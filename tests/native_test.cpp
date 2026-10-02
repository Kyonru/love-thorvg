#include "love_thorvg.h"

#include <cassert>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <vector>

int main()
{
    const char* svg =
        "<svg xmlns='http://www.w3.org/2000/svg' width='4' height='4' viewBox='0 0 4 4'>"
        "<rect width='4' height='4' fill='#ff0000'/></svg>";
    char error[512] = {};
    love_thorvg_document* document = nullptr;
    const int created = love_thorvg_document_create(
        svg, std::strlen(svg), "svg", "", 0, &document, error, sizeof(error));
    if (created != LOVE_THORVG_OK) {
        std::cerr << error << '\n';
        return 1;
    }

    assert(love_thorvg_abi_version() == 1);
    assert(love_thorvg_document_intrinsic_width(document) == 4.0f);
    assert(love_thorvg_document_intrinsic_height(document) == 4.0f);

    std::vector<uint32_t> pixels(8 * 8, 0);
    const int rendered = love_thorvg_document_render(
        document, pixels.data(), 8, 8, 8, 0.0f, error, sizeof(error));
    if (rendered != LOVE_THORVG_OK) {
        std::cerr << error << '\n';
        love_thorvg_document_destroy(document);
        return 1;
    }

    const auto* bytes = reinterpret_cast<const uint8_t*>(pixels.data());
    const size_t center = (4 * 8 + 4) * 4;
    assert(bytes[center] > 240);
    assert(bytes[center + 1] < 10);
    assert(bytes[center + 2] < 10);
    assert(bytes[center + 3] > 240);

    pixels.assign(16 * 8, 0);
    assert(love_thorvg_document_render(
        document, pixels.data(), 16, 8, 16, 0.0f, error, sizeof(error)) == LOVE_THORVG_OK);
    bytes = reinterpret_cast<const uint8_t*>(pixels.data());
    assert(bytes[(4 * 16 + 8) * 4 + 3] > 240);

    love_thorvg_document_destroy(document);

    const char* lottie = R"json({
      "v":"5.7.4","fr":30,"ip":0,"op":30,"w":32,"h":32,"nm":"smoke-test",
      "ddd":0,"assets":[],"layers":[{
        "ddd":0,"ind":1,"ty":4,"nm":"square","sr":1,
        "ks":{"o":{"a":0,"k":100},"r":{"a":0,"k":0},"p":{"a":0,"k":[16,16,0]},
              "a":{"a":0,"k":[0,0,0]},"s":{"a":0,"k":[100,100,100]}},
        "ao":0,"shapes":[
          {"ty":"rc","d":1,"s":{"a":0,"k":[20,20]},"p":{"a":0,"k":[0,0]},"r":{"a":0,"k":2}},
          {"ty":"fl","c":{"a":0,"k":[0.1,0.8,0.4,1]},"o":{"a":0,"k":100},"r":1}
        ],"ip":0,"op":30,"st":0,"bm":0
      }]
    })json";
    document = nullptr;
    const int lottie_created = love_thorvg_document_create(
        lottie, std::strlen(lottie), "lottie+json", "", 0, &document, error, sizeof(error));
    if (lottie_created != LOVE_THORVG_OK) {
        std::cerr << error << '\n';
        return 1;
    }
    assert(love_thorvg_document_total_frames(document) == 30.0f);
    assert(love_thorvg_document_duration(document) == 1.0f);
    pixels.assign(32 * 32, 0);
    assert(love_thorvg_document_render(
        document, pixels.data(), 32, 32, 32, 0.5f, error, sizeof(error)) == LOVE_THORVG_OK);
    bytes = reinterpret_cast<const uint8_t*>(pixels.data());
    assert(bytes[(16 * 32 + 16) * 4 + 3] > 240);
    love_thorvg_document_destroy(document);

    std::cout << "love-thorvg native API test passed\n";
    return 0;
}
