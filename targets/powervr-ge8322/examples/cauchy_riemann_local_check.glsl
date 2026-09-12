/*
 * Cauchy–Riemann Local Complex Differentiability Checker
 *
 * Canonical name: Cauchy–Riemann local complex differentiability check
 * Technical alias: check_holomorphic
 * Requested vocabulary alias: check_smooth
 * Plain-language alias: check_local_smoothness
 * Conformal alias: check_conformal
 *
 * For f(x + iy) = u(x,y) + i v(x,y), supply
 *
 *     du = (∂u/∂x, ∂u/∂y)
 *     dv = (∂v/∂x, ∂v/∂y).
 *
 * The Cauchy–Riemann residual is
 *
 *     (∂u/∂x - ∂v/∂y,
 *      ∂u/∂y + ∂v/∂x).
 *
 * This is a local numerical oracle.  When the derivatives themselves come
 * from an analytic construction, it is also a cheap implementation check.
 * Central-difference sampling is provided below for diagnostics, but a finite
 * sample grid by itself is not a proof over a continuum.
 *
 * `check_smooth` and `check_local_smoothness` are naming aliases only: the
 * Cauchy–Riemann equations are not a general test for arbitrary real
 * smoothness.  `check_conformal` additionally requires a nonzero complex
 * derivative, because a holomorphic map is conformal only away from critical
 * points.
 *
 * Target: PowerVR GE8322, GLSL ES 3.00.
 */

precision highp float;

struct CauchyRiemannCheck {
    vec2 residual;
    float residual_squared;
    float derivative_squared;
    bool locally_complex_differentiable;
    bool conformal;
};

CauchyRiemannCheck cauchy_riemann_local_check(
    vec2 du,
    vec2 dv,
    float tolerance,
    float derivative_floor
) {
    CauchyRiemannCheck result;

    result.residual = vec2(
        du.x - dv.y,
        du.y + dv.x
    );
    result.residual_squared = dot(result.residual, result.residual);

    float derivative_energy = dot(du, du) + dot(dv, dv);
    float scale_squared = max(1.0, derivative_energy);
    float tolerance_squared = tolerance * tolerance * scale_squared;

    /* f'(z) = u_x + i v_x when the Cauchy–Riemann equations hold. */
    result.derivative_squared = du.x * du.x + dv.x * dv.x;
    result.locally_complex_differentiable =
        result.residual_squared <= tolerance_squared;
    result.conformal =
        result.locally_complex_differentiable &&
        result.derivative_squared > derivative_floor * derivative_floor;

    return result;
}

CauchyRiemannCheck cauchy_riemann_from_samples(
    vec2 f_x_minus,
    vec2 f_x_plus,
    vec2 f_y_minus,
    vec2 f_y_plus,
    float step,
    float tolerance,
    float derivative_floor
) {
    float inverse_span = 0.5 / max(abs(step), 1.0e-12);
    vec2 dfdx = (f_x_plus - f_x_minus) * inverse_span;
    vec2 dfdy = (f_y_plus - f_y_minus) * inverse_span;

    vec2 du = vec2(dfdx.x, dfdy.x);
    vec2 dv = vec2(dfdx.y, dfdy.y);

    return cauchy_riemann_local_check(
        du,
        dv,
        tolerance,
        derivative_floor
    );
}

bool check_holomorphic(vec2 du, vec2 dv, float tolerance) {
    return cauchy_riemann_local_check(du, dv, tolerance, 0.0)
        .locally_complex_differentiable;
}

bool check_smooth(vec2 du, vec2 dv, float tolerance) {
    return check_holomorphic(du, dv, tolerance);
}

bool check_local_smoothness(vec2 du, vec2 dv, float tolerance) {
    return check_holomorphic(du, dv, tolerance);
}

bool check_conformal(
    vec2 du,
    vec2 dv,
    float tolerance,
    float derivative_floor
) {
    return cauchy_riemann_local_check(
        du,
        dv,
        tolerance,
        derivative_floor
    ).conformal;
}
