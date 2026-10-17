// Emscripten needs an entry point even though consumers call only the exported
// love-thorvg C ABI.
int main()
{
    return 0;
}
