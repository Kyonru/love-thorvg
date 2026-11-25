#include "love_thorvg.h"
#include <algorithm>
#include <cassert>
#include <cstring>
#include <fstream>
#include <iterator>
#include <iostream>
#include <string>
#include <vector>

size_t resolve_font(const char* source, int type, void* output, size_t capacity, void* data)
{
    assert(type == LOVE_THORVG_ASSET_FONT);
    if (std::strcmp(source, "name:TestFont") != 0) return 0;
    const auto& bytes = *static_cast<std::vector<char>*>(data);
    if (output && capacity >= bytes.size()) std::memcpy(output, bytes.data(), bytes.size());
    return bytes.size();
}

int main(int argc, char** argv)
{
    assert(argc == 2);
    std::ifstream file(argv[1], std::ios::binary);
    std::vector<char> bytes{std::istreambuf_iterator<char>(file), {}};
    assert(!bytes.empty());
    const char* svg = "<svg xmlns='http://www.w3.org/2000/svg' width='128' height='128'>"
        "<text x='8' y='90' font-family='TestFont' font-size='80' fill='#ffffff'>AB</text></svg>";
    char error[512] = {};
    const char* names[] = {"TestFont", "MissingFont"};
    auto create = [&](std::vector<char>& font, size_t count, love_thorvg_document** result) {
        return love_thorvg_document_create_with_fonts(svg, std::strlen(svg), "svg", "", 0,
            resolve_font, &font, names, count, result, error, sizeof(error));
    };
    auto render = [&](love_thorvg_document* document, unsigned size) {
        std::vector<uint32_t> pixels(size * size);
        assert(love_thorvg_document_render(document, pixels.data(), size, size, size, 0, error, sizeof(error)) == LOVE_THORVG_OK);
        assert(std::count_if(pixels.begin(), pixels.end(), [](uint32_t p) {return (p >> 24) > 0;}) > 100);
        return pixels;
    };
    love_thorvg_document *first = nullptr, *second = nullptr, *failed = nullptr;
    assert(create(bytes, 1, &first) == LOVE_THORVG_OK);
    const auto expected = render(first, 128);
    assert(create(bytes, 1, &second) == LOVE_THORVG_OK);
    assert(render(second, 128) == expected);
    auto different = bytes;
    different.push_back(0);
    assert(create(different, 1, &failed) == LOVE_THORVG_LOAD_ERROR && !failed);
    assert(std::strstr(error, "different data"));
    assert(create(bytes, 2, &failed) == LOVE_THORVG_LOAD_ERROR && !failed);
    assert(std::strstr(error, "font not found"));
    love_thorvg_document_destroy(first);
    assert(render(second, 128) == expected);
    render(second, 256);
    love_thorvg_document_destroy(second);
    // Last-owner cleanup must allow the same family to load new bytes.
    assert(create(different, 1, &first) == LOVE_THORVG_OK);
    render(first, 128);
    love_thorvg_document_destroy(first);
    std::vector<char> invalid = {'b', 'a', 'd'};
    assert(create(invalid, 1, &failed) == LOVE_THORVG_LOAD_ERROR && !failed);
    assert(std::strstr(error, "font decode failed"));
    assert(create(bytes, 1, &first) == LOVE_THORVG_OK);
    render(first, 128);
    love_thorvg_document_destroy(first);
    std::cout << "PASS: SVG font pixels, shared lifetime, conflicts, missing/invalid fonts and failure cleanup\n";
}
