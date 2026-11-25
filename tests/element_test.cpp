#include "love_thorvg.h"
#include <cassert>
#include <cmath>
#include <cstring>
#include <iostream>
#include <limits>
#include <vector>

int main()
{
    const char* svg = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 40 40'>"
        "<defs><rect id='tile' x='2' y='3' width='8' height='6' fill='red' stroke='red' stroke-width='2'/></defs>"
        "<g id='moving'><use href='#tile'/></g>"
        "<g transform='translate(0 20)'><g id='moving'><use href='#tile'/></g></g></svg>";
    love_thorvg_document* doc = nullptr;
    char error[512] = {};
    assert(love_thorvg_document_create(svg, std::strlen(svg), "svg", "", 0, &doc, error, sizeof(error)) == 0);
    float bounds[4] = {};
    int result = love_thorvg_document_element_bounds(doc, "moving", bounds, error, sizeof(error));
    if (result) std::cerr << error << '\n';
    assert(result == 0);
    for (int i=0; i<4; ++i) std::cout << bounds[i] << ' ';
    std::cout << '\n';
    assert(std::abs(bounds[0]-2) < .01 && std::abs(bounds[1]-3) < .01);
    assert(std::abs(bounds[2]-8) < .01 && std::abs(bounds[3]-6) < .01);
    std::vector<uint32_t> pixels(40*40);
    auto render = [&]() { assert(love_thorvg_document_render(doc, pixels.data(), 40, 40, 40, 0, error, sizeof(error)) == 0); };
    render();
    assert(pixels[5*40+5] != 0 && pixels[25*40+5] != 0);
    float matrix[] = {1, 0, 0, 1, 15, 0};
    assert(love_thorvg_document_set_element(doc, "moving", matrix, .5f, error, sizeof(error)) == 0);
    render();
    assert(pixels[5*40+5] == 0 && pixels[25*40+5] == 0);
    assert((pixels[5*40+20] >> 24) == 128 && (pixels[25*40+20] >> 24) == 128);
    // Repeated updates replace, rather than accumulate, transforms.
    assert(love_thorvg_document_set_element(doc, "moving", matrix, .5f, error, sizeof(error)) == 0);
    render();
    assert((pixels[5*40+20] >> 24) == 128);
    matrix[4] = 0;
    assert(love_thorvg_document_set_element(doc, "moving", matrix, 1, error, sizeof(error)) == 0);
    render();
    assert(pixels[5*40+5] != 0 && pixels[25*40+5] != 0);
    assert(love_thorvg_document_set_element(doc, "missing", matrix, 1, error, sizeof(error)) != 0);
    matrix[0] = std::numeric_limits<float>::quiet_NaN();
    assert(love_thorvg_document_set_element(doc, "moving", matrix, 1, error, sizeof(error)) != 0);
    assert(love_thorvg_document_element_bounds(nullptr, "moving", bounds, error, sizeof(error)) != 0);
    love_thorvg_document_destroy(doc);
    std::cout << "PASS: SVG bounds, cloned instances, transforms, opacity and invalid input\n";
}
