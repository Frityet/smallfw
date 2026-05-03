@import SFStdLib;
@import SFStdLib.Collections;
@import SFStdLib.Exceptions;
@import SFStdLib.Reflection;

int main(void)
{
    auto number = [Number numberWithInt:7];
    auto array = [Array arrayWithObjects:(id[]){number} count:1U];
    auto exception = [Exception exceptionWithMessage:@"module"];
    auto reflected_class = [Reflection classNamed:"Object"];
    return number != nullptr && array != nullptr && exception != nullptr && reflected_class != nullptr ? 0 : 1;
}
