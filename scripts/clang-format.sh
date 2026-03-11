#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mode="format"
if [[ "${1-}" == "--check" ]]; then
    mode="check"
    shift
fi

# clang-format misformats iso646 alternative tokens in .c files unless the
# C++-family parser is selected explicitly.
cpp_style='{Language: Cpp, BasedOnStyle: LLVM, IndentWidth: 4, TabWidth: 4, UseTab: Never, ColumnLimit: 0, ContinuationIndentWidth: 4, IndentCaseLabels: true, PointerAlignment: Right, ReferenceAlignment: Right, SortIncludes: Never, IncludeBlocks: Preserve, ReflowComments: false, AllowShortFunctionsOnASingleLine: None, BreakBeforeBraces: Custom, BraceWrapping: {AfterFunction: true, SplitEmptyFunction: true}}'

is_objc_header() {
    rg -q '@interface|@protocol|@property|@class' "$1"
}

style_for_file() {
    local file="$1"
    case "$file" in
        *.m|*.mm)
            printf '%s\n' "file"
            ;;
        *.h)
            if is_objc_header "$file"; then
                printf '%s\n' "file"
            else
                printf '%s\n' "$cpp_style"
            fi
            ;;
        *.c)
            printf '%s\n' "$cpp_style"
            ;;
        *)
            return 1
            ;;
    esac
}

format_file() {
    local file="$1"
    local style
    style="$(style_for_file "$file")"
    if [[ "$style" == "file" ]]; then
        clang-format -style=file -i "$file"
    else
        clang-format -style="$style" -i "$file"
    fi
}

check_file() {
    local file="$1"
    local style
    local tmp
    style="$(style_for_file "$file")"
    tmp="$(mktemp)"
    if [[ "$style" == "file" ]]; then
        clang-format -style=file "$file" > "$tmp"
    else
        clang-format -style="$style" "$file" > "$tmp"
    fi
    if ! cmp -s "$file" "$tmp"; then
        printf 'needs formatting: %s\n' "$file" >&2
        rm -f "$tmp"
        return 1
    fi
    rm -f "$tmp"
}

if [[ "$#" -gt 0 ]]; then
    files=("$@")
else
    mapfile -t files < <(find src tests -type f \( -name '*.c' -o -name '*.h' -o -name '*.m' -o -name '*.mm' \) | sort)
fi

status=0
for file in "${files[@]}"; do
    if [[ "$mode" == "check" ]]; then
        if ! check_file "$file"; then
            status=1
        fi
    else
        format_file "$file"
    fi
done

exit "$status"
