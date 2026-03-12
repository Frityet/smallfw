import("core.base.option")
import("lib.detect.find_tool")

local CPP_STYLE = "{Language: Cpp, BasedOnStyle: LLVM, IndentWidth: 4, TabWidth: 4, UseTab: Never, ColumnLimit: 0, ContinuationIndentWidth: 4, IndentCaseLabels: true, PointerAlignment: Right, ReferenceAlignment: Right, SortIncludes: Never, IncludeBlocks: Preserve, ReflowComments: false, AllowShortFunctionsOnASingleLine: None, BreakBeforeBraces: Custom, BraceWrapping: {AfterFunction: true, SplitEmptyFunction: true}}"

local DEFAULT_PATTERNS = {
    "src/**.c",
    "src/**.h",
    "src/**.m",
    "src/**.mm",
    "tests/**.c",
    "tests/**.h",
    "tests/**.m",
    "tests/**.mm",
    "benchmarks/**.c",
    "benchmarks/**.h",
    "benchmarks/**.m",
    "benchmarks/**.mm",
    "examples/**.c",
    "examples/**.h",
    "examples/**.m",
    "examples/**.mm",
}

local function _is_supported_file(file)
    local ext = path.extension(file)
    return ext == ".c" or ext == ".h" or ext == ".m" or ext == ".mm"
end

local function _looks_like_pattern(value)
    return value:find("%*", 1, false) ~= nil or
           value:find("%?", 1, false) ~= nil or
           value:find("|", 1, true) ~= nil
end

local function _is_objc_header(file)
    local content = io.readfile(file) or ""
    return content:find("@interface", 1, true) ~= nil or
           content:find("@protocol", 1, true) ~= nil or
           content:find("@property", 1, true) ~= nil or
           content:find("@class", 1, true) ~= nil
end

local function _style_for_file(file)
    local ext = path.extension(file)
    if ext == ".m" or ext == ".mm" then
        return "file"
    end
    if ext == ".h" then
        if _is_objc_header(file) then
            return "file"
        end
        return CPP_STYLE
    end
    if ext == ".c" then
        return CPP_STYLE
    end
    raise("unsupported file type: " .. file)
end

local function _relative_to_project(file)
    return path.relative(path.absolute(file), os.projectdir())
end

local function _collect_files(inputs)
    local files = {}
    local seen = {}

    for _, input in ipairs(inputs) do
        local matches = {}
        if _looks_like_pattern(input) then
            matches = os.files(input)
        elseif os.isfile(input) then
            matches = {input}
        else
            raise("no such file or pattern match: " .. input)
        end

        if #matches == 0 then
            raise("pattern matched no files: " .. input)
        end

        for _, file in ipairs(matches) do
            local absolute = path.absolute(file)
            if not _is_supported_file(absolute) then
                raise("unsupported file type: " .. file)
            end
            if not seen[absolute] then
                seen[absolute] = true
                table.insert(files, absolute)
            end
        end
    end

    table.sort(files)
    return files
end

local function _default_files()
    return _collect_files(DEFAULT_PATTERNS)
end

local function _clang_format_args(file, inplace)
    local style = _style_for_file(file)
    local args = {"-style=" .. style}
    if inplace then
        table.insert(args, "-i")
    end
    table.insert(args, file)
    return args
end

local function _format_file(tool, file)
    os.execv(tool.program, _clang_format_args(file, true))
    print("formatted " .. _relative_to_project(file))
end

local function _check_file(tool, file)
    local formatted = os.iorunv(tool.program, _clang_format_args(file, false))
    local current = io.readfile(file) or ""
    if formatted ~= current then
        print("needs formatting: " .. _relative_to_project(file))
        return false
    end
    print("ok " .. _relative_to_project(file))
    return true
end

function main()
    local tool = find_tool("clang-format")
    assert(tool and tool.program, "clang-format not found")
    local files = option.get("files")
    if files == nil or #files == 0 then
        files = _default_files()
    else
        files = _collect_files(files)
    end

    local check_only = option.get("check")
    local failed = false
    for _, file in ipairs(files) do
        if check_only then
            if not _check_file(tool, file) then
                failed = true
            end
        else
            _format_file(tool, file)
        end
    end

    if failed then
        raise("clang-format check failed")
    end
end
