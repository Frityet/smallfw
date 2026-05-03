#pragma once

#include <cstdint>

#ifndef LLVM_PLUGIN_API_VERSION
#    define LLVM_PLUGIN_API_VERSION 1
#endif

namespace llvm {

class PassBuilder;

struct PassPluginLibraryInfo {
    uint32_t APIVersion;
    const char *PluginName;
    const char *PluginVersion;
    void (*RegisterPassBuilderCallbacks)(PassBuilder &);
};

} // namespace llvm
