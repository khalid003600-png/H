#include <algorithm>
#include <cmath>
#include <iostream>

struct Size {
    double width;
    double height;
};

struct Rect {
    double x;
    double y;
    double width;
    double height;
};

static Rect aspectFit(Size image, Size target) {
    const double scale = std::min(target.width / image.width,
                                  target.height / image.height);
    const double width = image.width * scale;
    const double height = image.height * scale;
    return {(target.width - width) * 0.5,
            (target.height - height) * 0.5,
            width,
            height};
}

static bool nearlyEqual(double lhs, double rhs) {
    return std::abs(lhs - rhs) < 0.01;
}

static bool validateCase(const char *name, Size image, Size target, Rect expected) {
    const Rect actual = aspectFit(image, target);
    const bool insideTarget = actual.x >= -0.01 && actual.y >= -0.01 &&
                              actual.x + actual.width <= target.width + 0.01 &&
                              actual.y + actual.height <= target.height + 0.01;
    const bool matches = nearlyEqual(actual.x, expected.x) &&
                         nearlyEqual(actual.y, expected.y) &&
                         nearlyEqual(actual.width, expected.width) &&
                         nearlyEqual(actual.height, expected.height);
    if (insideTarget && matches) {
        std::cout << "[PASS] " << name << '\n';
        return true;
    }
    std::cerr << "[FAIL] " << name << " -> "
              << actual.x << ',' << actual.y << ' '
              << actual.width << 'x' << actual.height << '\n';
    return false;
}

int main() {
    int failures = 0;
    failures += !validateCase("9:16 portrait fills a 9:16 preview",
                              {1080.0, 1920.0},
                              {1080.0, 1920.0},
                              {0.0, 0.0, 1080.0, 1920.0});
    failures += !validateCase("4:3 portrait remains complete and centered",
                              {3024.0, 4032.0},
                              {1080.0, 1920.0},
                              {0.0, 240.0, 1080.0, 1440.0});
    failures += !validateCase("landscape input remains complete in portrait preview",
                              {1920.0, 1080.0},
                              {1080.0, 1920.0},
                              {0.0, 656.25, 1080.0, 607.5});
    failures += !validateCase("portrait input remains complete in landscape buffer",
                              {1080.0, 1920.0},
                              {1920.0, 1080.0},
                              {656.25, 0.0, 607.5, 1080.0});
    std::cout << "Virtual-camera geometry result: "
              << (4 - failures) << " passed, " << failures << " failed\n";
    return failures == 0 ? 0 : 1;
}
