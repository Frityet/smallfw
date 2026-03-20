#include <optional>
#include <string>
#include <vector>

#include <clang/AST/ASTConsumer.h>
#include <clang/AST/ASTContext.h>
#include <clang/AST/Attr.h>
#include <clang/AST/Decl.h>
#include <clang/AST/DeclObjC.h>
#include <clang/AST/Expr.h>
#include <clang/AST/ExprCXX.h>
#include <clang/AST/ExprObjC.h>
#include <clang/AST/RecursiveASTVisitor.h>
#include <clang/Basic/IdentifierTable.h>
#include <clang/Basic/ParsedAttrInfo.h>
#include <clang/Frontend/CompilerInstance.h>
#include <clang/Frontend/FrontendPluginRegistry.h>
#include <clang/Sema/ParsedAttr.h>
#include <clang/Sema/Sema.h>
#include <clang/Sema/SemaConsumer.h>

#include <llvm/ADT/SmallVector.h>
#include <llvm/ADT/DenseMap.h>
#include <llvm/ADT/SmallPtrSet.h>
#include <llvm/ADT/StringRef.h>
#include <llvm/IR/Constants.h>
#include <llvm/IR/Function.h>
#include <llvm/IR/GlobalVariable.h>
#include <llvm/IR/IRBuilder.h>
#include <llvm/IR/IntrinsicInst.h>
#include <llvm/IR/Instructions.h>
#include <llvm/IR/Module.h>
#include <llvm/IR/PassManager.h>
#include <llvm/Passes/PassBuilder.h>
#include <llvm/Passes/PassPlugin.h>

using namespace clang;

namespace {

constexpr llvm::StringLiteral kPluginName = "smallfw-generics";
constexpr llvm::StringLiteral kAnnotateName = "smallfw.encode_generics";
constexpr llvm::StringLiteral kMarkerFunctionName = "__smallfw_attach_generic_type_class";
constexpr llvm::StringLiteral kSetterFunctionName = "sf_object_set_generic_type_class";

static bool hasGenericMetadataAnnotation(const ObjCInterfaceDecl *decl)
{
    if (decl == nullptr) {
        return false;
    }

    for (const ObjCInterfaceDecl *candidate : decl->redecls()) {
        for (const auto *attr : candidate->specific_attrs<AnnotateAttr>()) {
            if (attr->getAnnotation() == kAnnotateName) {
                return true;
            }
        }
    }
    return false;
}

static const Expr *stripNoOpWrappers(const Expr *expr)
{
    while (expr != nullptr) {
        expr = expr->IgnoreParens();
        if (const auto *with_cleanups = dyn_cast<ExprWithCleanups>(expr)) {
            expr = with_cleanups->getSubExpr();
            continue;
        }
        if (const auto *implicit_cast = dyn_cast<ImplicitCastExpr>(expr)) {
            expr = implicit_cast->getSubExpr();
            continue;
        }
        if (const auto *materialized = dyn_cast<MaterializeTemporaryExpr>(expr)) {
            expr = materialized->getSubExpr();
            continue;
        }
        if (const auto *bind = dyn_cast<CXXBindTemporaryExpr>(expr)) {
            expr = bind->getSubExpr();
            continue;
        }
        break;
    }
    return expr;
}

static bool isSupportedAllocSelector(const ObjCMessageExpr *message)
{
    if (message == nullptr || !message->isClassMessage()) {
        return false;
    }

    const std::string selector = message->getSelector().getAsString();
    return selector == "allocWithAllocator:" || selector == "allocWithParent:" || selector == "allocInPlace:size:";
}

static std::string classNameForTypeArgument(QualType type_arg)
{
    const auto *arg_ptr_type = type_arg->getAs<ObjCObjectPointerType>();
    if (arg_ptr_type == nullptr) {
        return {};
    }

    ObjCInterfaceDecl *arg_iface = arg_ptr_type->getInterfaceDecl();
    if (arg_iface == nullptr) {
        return {};
    }
    return arg_iface->getNameAsString();
}

static bool extractSpecializedClassName(QualType type, std::string &class_name)
{
    const auto *object_ptr_type = type->getAs<ObjCObjectPointerType>();
    if (object_ptr_type == nullptr || !object_ptr_type->isSpecializedAsWritten()) {
        return false;
    }

    ObjCInterfaceDecl *iface = object_ptr_type->getInterfaceDecl();
    if (iface == nullptr || !hasGenericMetadataAnnotation(iface)) {
        return false;
    }

    llvm::ArrayRef<QualType> type_args = object_ptr_type->getTypeArgsAsWritten();
    if (type_args.size() != 1U) {
        return false;
    }

    class_name = classNameForTypeArgument(type_args.front());
    return !class_name.empty();
}

static bool matchGenericConstruction(ASTContext &, const Expr *expr, std::string &class_name)
{
    const auto *message = dyn_cast_or_null<ObjCMessageExpr>(stripNoOpWrappers(expr));
    if (message == nullptr) {
        return false;
    }

    if (isSupportedAllocSelector(message)) {
        return extractSpecializedClassName(message->getType(), class_name);
    }

    if (!message->isInstanceMessage()) {
        return false;
    }
    if (!llvm::StringRef(message->getSelector().getAsString()).starts_with("init")) {
        return false;
    }

    const auto *receiver = dyn_cast_or_null<ObjCMessageExpr>(stripNoOpWrappers(message->getInstanceReceiver()));
    if (!isSupportedAllocSelector(receiver)) {
        return false;
    }
    return extractSpecializedClassName(message->getType(), class_name);
}

class GenericMetadataTransformer final {
public:
    explicit GenericMetadataTransformer(Sema &sema)
        : sema_(sema)
        , context_(sema.Context)
    {}

    void transformDecl(Decl *decl)
    {
        if (auto *function = dyn_cast_or_null<FunctionDecl>(decl); function != nullptr && function->hasBody()) {
            transformStmt(function->getBody());
            return;
        }
        if (auto *method = dyn_cast_or_null<ObjCMethodDecl>(decl); method != nullptr && method->hasBody()) {
            transformStmt(method->getBody());
            return;
        }
        if (auto *impl = dyn_cast_or_null<ObjCImplDecl>(decl)) {
            for (ObjCMethodDecl *method : impl->methods()) {
                if (method != nullptr && method->hasBody()) {
                    transformStmt(method->getBody());
                }
            }
        }
    }

private:
    void transformStmt(Stmt *stmt)
    {
        if (stmt == nullptr) {
            return;
        }

        for (Stmt *&child : stmt->children()) {
            if (auto *child_expr = dyn_cast_or_null<Expr>(child)) {
                child = transformExpr(child_expr);
            } else {
                transformStmt(child);
            }
        }
    }

    Expr *transformExpr(Expr *expr)
    {
        if (expr == nullptr) {
            return nullptr;
        }

        std::string class_name;
        if (matchGenericConstruction(context_, expr, class_name)) {
            return buildMarkerWrapper(expr, class_name);
        }

        for (Stmt *&child : expr->children()) {
            if (auto *child_expr = dyn_cast_or_null<Expr>(child)) {
                child = transformExpr(child_expr);
            } else {
                transformStmt(child);
            }
        }
        return expr;
    }

    Expr *buildMarkerWrapper(Expr *expr, llvm::StringRef class_name)
    {
        FunctionDecl *marker = ensureMarkerFunction();
        Expr *callee = sema_.BuildDeclRefExpr(marker, marker->getType(), VK_LValue, expr->getExprLoc());
        if (callee == nullptr) {
            return expr;
        }

        ExprResult object_arg =
            sema_.ImpCastExprToType(expr, context_.getObjCIdType(), CK_BitCast, VK_PRValue);
        if (object_arg.isInvalid()) {
            return expr;
        }

        Expr *class_name_literal = buildClassNameLiteral(class_name, expr->getExprLoc());
        if (class_name_literal == nullptr) {
            return expr;
        }

        llvm::SmallVector<Expr *, 2> args = {object_arg.get(), class_name_literal};
        ExprResult call = sema_.BuildCallExpr(nullptr, callee, expr->getExprLoc(), args, expr->getEndLoc());
        if (call.isInvalid()) {
            return expr;
        }

        if (context_.hasSameType(call.get()->getType(), expr->getType())) {
            return call.get();
        }

        ExprResult casted = sema_.ImpCastExprToType(call.get(), expr->getType(), CK_BitCast, expr->getValueKind());
        return casted.isInvalid() ? expr : casted.get();
    }

    Expr *buildClassNameLiteral(llvm::StringRef class_name, SourceLocation loc)
    {
        QualType const_char_type = context_.getConstType(context_.CharTy);
        QualType literal_type = context_.getStringLiteralArrayType(const_char_type,
                                                                  static_cast<unsigned>(class_name.size() + 1U));
        auto *literal =
            StringLiteral::Create(context_, class_name, StringLiteralKind::Ordinary, false, literal_type, {loc});
        ExprResult decay =
            sema_.ImpCastExprToType(literal, context_.getPointerType(const_char_type), CK_ArrayToPointerDecay);
        return decay.isInvalid() ? nullptr : decay.get();
    }

    FunctionDecl *ensureMarkerFunction()
    {
        if (marker_function_ != nullptr) {
            return marker_function_;
        }

        TranslationUnitDecl *tu = context_.getTranslationUnitDecl();
        DeclarationName name(&context_.Idents.get(kMarkerFunctionName.data()));
        for (NamedDecl *decl : tu->lookup(name)) {
            if (auto *function = dyn_cast<FunctionDecl>(decl)) {
                marker_function_ = function;
                return marker_function_;
            }
        }

        QualType id_type = context_.getObjCIdType();
        QualType const_char_ptr_type = context_.getPointerType(context_.getConstType(context_.CharTy));
        QualType function_type = context_.getFunctionType(id_type, {id_type, const_char_ptr_type}, {});

        marker_function_ = FunctionDecl::Create(context_,
                                                tu,
                                                SourceLocation(),
                                                SourceLocation(),
                                                name,
                                                function_type,
                                                context_.getTrivialTypeSourceInfo(function_type),
                                                SC_Extern,
                                                false,
                                                false,
                                                true);
        marker_function_->setImplicit();

        auto *object_param = ParmVarDecl::Create(context_,
                                                 marker_function_,
                                                 SourceLocation(),
                                                 SourceLocation(),
                                                 &context_.Idents.get("obj"),
                                                 id_type,
                                                 nullptr,
                                                 SC_None,
                                                 nullptr);
        auto *class_name_param = ParmVarDecl::Create(context_,
                                                     marker_function_,
                                                     SourceLocation(),
                                                     SourceLocation(),
                                                     &context_.Idents.get("class_name"),
                                                     const_char_ptr_type,
                                                     nullptr,
                                                     SC_None,
                                                     nullptr);

        llvm::SmallVector<ParmVarDecl *, 2> params = {object_param, class_name_param};
        marker_function_->setParams(params);
        tu->addDecl(marker_function_);
        return marker_function_;
    }

    Sema &sema_;
    ASTContext &context_;
    FunctionDecl *marker_function_ = nullptr;
};

class GenericMetadataConsumer final : public SemaConsumer {
public:
    bool HandleTopLevelDecl(DeclGroupRef group) override
    {
        if (sema_ == nullptr) {
            return true;
        }

        GenericMetadataTransformer transformer(*sema_);
        for (Decl *decl : group) {
            transformer.transformDecl(decl);
        }
        return true;
    }

    void InitializeSema(Sema &sema) override
    {
        sema_ = &sema;
    }

    void ForgetSema() override
    {
        sema_ = nullptr;
    }

private:
    Sema *sema_ = nullptr;
};

class GenericMetadataAttrInfo final : public ParsedAttrInfo {
public:
    GenericMetadataAttrInfo()
    {
        static constexpr Spelling spellings[] = {
            {ParsedAttr::AS_GNU, "sf_encode_generics"},
            {ParsedAttr::AS_C23, "sf_encode_generics"},
            {ParsedAttr::AS_C23, "clang::sf_encode_generics"},
            {ParsedAttr::AS_CXX11, "sf_encode_generics"},
            {ParsedAttr::AS_CXX11, "clang::sf_encode_generics"},
        };
        Spellings = spellings;
    }

    bool acceptsLangOpts(const LangOptions &lang_opts) const override
    {
        return lang_opts.ObjC;
    }

    bool diagAppertainsToDecl(Sema &sema, const ParsedAttr &attr, const Decl *decl) const override
    {
        if (isa<ObjCInterfaceDecl>(decl)) {
            return true;
        }

        unsigned diag = sema.getDiagnostics().getCustomDiagID(
            DiagnosticsEngine::Error, "'sf_encode_generics' only applies to Objective-C interfaces");
        sema.Diag(attr.getLoc(), diag);
        return false;
    }

    AttrHandling handleDeclAttribute(Sema &sema, Decl *decl, const ParsedAttr &attr) const override
    {
        auto *iface = dyn_cast<ObjCInterfaceDecl>(decl);
        if (iface == nullptr) {
            return AttributeNotApplied;
        }
        if (iface->getTypeParamList() == nullptr || iface->getTypeParamList()->size() == 0U) {
            unsigned diag = sema.getDiagnostics().getCustomDiagID(
                DiagnosticsEngine::Error, "'sf_encode_generics' requires a generic Objective-C interface");
            sema.Diag(attr.getLoc(), diag);
            return AttributeNotApplied;
        }

        iface->addAttr(AnnotateAttr::CreateImplicit(sema.Context, kAnnotateName, nullptr, 0));
        return AttributeApplied;
    }
};

class GenericMetadataPluginAction final : public PluginASTAction {
public:
    bool ParseArgs(const CompilerInstance &, const std::vector<std::string> &) override
    {
        return true;
    }

    ActionType getActionType() override
    {
        return AddBeforeMainAction;
    }

    std::unique_ptr<ASTConsumer> CreateASTConsumer(CompilerInstance &, llvm::StringRef) override
    {
        return std::make_unique<GenericMetadataConsumer>();
    }
};

struct StringLiteralInfo {
    std::string value;
};

static std::optional<StringLiteralInfo> extractStringLiteralInfo(llvm::Value *value)
{
    llvm::Value *base = value;
    if (auto *gep = llvm::dyn_cast<llvm::GEPOperator>(base)) {
        base = gep->getPointerOperand();
    }
    base = base->stripPointerCasts();

    auto *global = llvm::dyn_cast<llvm::GlobalVariable>(base);
    if (global == nullptr || !global->hasInitializer()) {
        return std::nullopt;
    }

    auto *data = llvm::dyn_cast<llvm::ConstantDataArray>(global->getInitializer());
    if (data == nullptr || (!data->isCString() && !data->isString())) {
        return std::nullopt;
    }

    llvm::StringRef string_value = data->isCString() ? data->getAsCString() : data->getAsString();
    const size_t terminator = string_value.find('\0');
    if (terminator != llvm::StringRef::npos) {
        string_value = string_value.take_front(terminator);
    }
    if (string_value.empty()) {
        return std::nullopt;
    }
    return StringLiteralInfo{string_value.str()};
}

static llvm::GlobalVariable *classReferenceGlobal(llvm::Module &module, llvm::StringRef class_name)
{
    llvm::Type *ptr_type = llvm::PointerType::getUnqual(module.getContext());
    const std::string symbol_name = ("._OBJC_REF_CLASS_" + class_name).str();

    if (llvm::GlobalVariable *global = module.getNamedGlobal(symbol_name); global != nullptr) {
        return global;
    }

    return new llvm::GlobalVariable(module,
                                    ptr_type,
                                    false,
                                    llvm::GlobalValue::ExternalLinkage,
                                    nullptr,
                                    symbol_name);
}

static llvm::Instruction *previousNonDebugInstruction(llvm::Instruction *instruction)
{
    llvm::Instruction *cursor = instruction != nullptr ? instruction->getPrevNode() : nullptr;
    while (cursor != nullptr && llvm::isa<llvm::DbgInfoIntrinsic>(cursor)) {
        cursor = cursor->getPrevNode();
    }
    return cursor;
}

static llvm::Instruction *nextNonDebugInstruction(llvm::Instruction *instruction)
{
    llvm::Instruction *cursor = instruction != nullptr ? instruction->getNextNode() : nullptr;
    while (cursor != nullptr && llvm::isa<llvm::DbgInfoIntrinsic>(cursor)) {
        cursor = cursor->getNextNode();
    }
    return cursor;
}

static bool isArcHelperCall(const llvm::CallBase *call, llvm::StringRef name)
{
    if (call == nullptr) {
        return false;
    }

    const llvm::Function *callee = call->getCalledFunction();
    return callee != nullptr && callee->getName() == name;
}

static bool isArcHelperInstruction(const llvm::Instruction *instruction)
{
    const auto *call = llvm::dyn_cast_or_null<llvm::CallBase>(instruction);
    if (call == nullptr) {
        return false;
    }
    const llvm::Function *callee = call->getCalledFunction();
    return callee != nullptr && callee->getName().starts_with("llvm.objc.");
}

class GenericMetadataLoweringPass final : public llvm::PassInfoMixin<GenericMetadataLoweringPass> {
public:
    llvm::PreservedAnalyses run(llvm::Module &module, llvm::ModuleAnalysisManager &)
    {
        llvm::SmallVector<llvm::CallBase *, 8> marker_calls;

        for (llvm::Function &function : module) {
            for (llvm::BasicBlock &block : function) {
                for (llvm::Instruction &instruction : block) {
                    auto *call = llvm::dyn_cast<llvm::CallBase>(&instruction);
                    if (call == nullptr) {
                        continue;
                    }

                    llvm::Value *callee_value = call->getCalledOperand();
                    if (callee_value == nullptr) {
                        continue;
                    }

                    auto *callee = llvm::dyn_cast<llvm::Function>(callee_value->stripPointerCasts());
                    if (callee != nullptr && callee->getName() == kMarkerFunctionName) {
                        marker_calls.push_back(call);
                    }
                }
            }
        }

        if (marker_calls.empty()) {
            return llvm::PreservedAnalyses::all();
        }

        llvm::LLVMContext &context = module.getContext();
        llvm::Type *ptr_type = llvm::PointerType::getUnqual(context);
        llvm::FunctionCallee setter = module.getOrInsertFunction(
            kSetterFunctionName.data(),
            llvm::FunctionType::get(llvm::Type::getVoidTy(context), {ptr_type, ptr_type}, false));

        for (llvm::CallBase *call : marker_calls) {
            auto class_name_info = extractStringLiteralInfo(call->getArgOperand(1));
            if (!class_name_info.has_value()) {
                continue;
            }

            llvm::IRBuilder<> builder(call);
            llvm::Value *object = call->getArgOperand(0);
            if (object->getType() != ptr_type) {
                object = builder.CreatePointerCast(object, ptr_type);
            }

            for (llvm::Instruction *previous = previousNonDebugInstruction(call);
                 previous != nullptr && isArcHelperInstruction(previous);
                 previous = previousNonDebugInstruction(previous)) {
                auto *previous_call = llvm::dyn_cast<llvm::CallBase>(previous);
                if (!isArcHelperCall(previous_call, "llvm.objc.release")) {
                    continue;
                }
                llvm::Value *released = previous_call->getArgOperand(0);
                if (released == object || released == call) {
                    previous->eraseFromParent();
                    break;
                }
            }
            if (llvm::Instruction *next = nextNonDebugInstruction(call)) {
                auto *next_call = llvm::dyn_cast<llvm::CallBase>(next);
                if (isArcHelperCall(next_call, "llvm.objc.release") &&
                    (next_call->getArgOperand(0) == object || next_call->getArgOperand(0) == call)) {
                    next->eraseFromParent();
                }
            }

            llvm::GlobalVariable *class_ref = classReferenceGlobal(module, class_name_info->value);
            llvm::Value *class_value = builder.CreateLoad(ptr_type, class_ref);
            builder.CreateCall(setter, {object, class_value});

            llvm::SmallVector<llvm::Instruction *, 4> arc_cleanup;
            for (llvm::User *user : call->users()) {
                auto *user_call = llvm::dyn_cast<llvm::CallBase>(user);
                if (!isArcHelperCall(user_call, "llvm.objc.retainAutoreleasedReturnValue")) {
                    continue;
                }
                user_call->replaceAllUsesWith(object);
                arc_cleanup.push_back(user_call);
            }

            llvm::Value *replacement = call->getArgOperand(0);
            if (replacement->getType() != call->getType()) {
                replacement = builder.CreateBitCast(replacement, call->getType());
            }
            call->replaceAllUsesWith(replacement);
            for (llvm::Instruction *instruction : arc_cleanup) {
                instruction->eraseFromParent();
            }
            call->eraseFromParent();
        }

        if (llvm::Function *marker = module.getFunction(kMarkerFunctionName); marker != nullptr && marker->use_empty()) {
            marker->eraseFromParent();
        }
        return llvm::PreservedAnalyses::none();
    }
};

} // namespace

static FrontendPluginRegistry::Add<GenericMetadataPluginAction> frontend_registry(kPluginName.data(),
                                                                                  "SmallFW generic class plugin");
static ParsedAttrInfoRegistry::Add<GenericMetadataAttrInfo> attr_registry("sf_encode_generics",
                                                                          "SmallFW generic class attribute");

extern "C" ::llvm::PassPluginLibraryInfo LLVM_ATTRIBUTE_WEAK llvmGetPassPluginInfo()
{
    return {
        LLVM_PLUGIN_API_VERSION,
        kPluginName.data(),
        "0.1",
        [](llvm::PassBuilder &pass_builder) {
            pass_builder.registerPipelineStartEPCallback(
                [](llvm::ModulePassManager &module_pass_manager, llvm::OptimizationLevel) {
                    module_pass_manager.addPass(GenericMetadataLoweringPass());
                });
        },
    };
}
