#pragma once

#include <algorithm>
#include <cmath>

// Small, time-based spring. Its position changes the artwork, never mouse input.
struct SCursorSpring {
    double value = 1.0;
    double velocity = 0.0;

    void step(double target, double dt, double stiffness, double damping) {
        dt = std::clamp(dt, 0.0, 0.04);
        const int steps = std::max(1, static_cast<int>(std::ceil(dt / 0.002)));
        const double h = dt / steps;
        for (int i = 0; i < steps; ++i) {
            velocity += (stiffness * (target - value) - damping * velocity) * h;
            value += velocity * h;
        }
        if (std::abs(target - value) < 0.0001 && std::abs(velocity) < 0.001) {
            value = target;
            velocity = 0.0;
        }
    }
};
