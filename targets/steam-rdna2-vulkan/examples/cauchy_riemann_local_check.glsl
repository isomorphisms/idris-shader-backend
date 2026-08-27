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
 * The residual is (u_x - v_y, u_y + v_x).  A small residual is the local
 * Cauchy–Riemann numerical check.  `check_conformal` additionally requires a
 * nonzero complex derivative.  The smoothness names are vocabulary aliases,
 * not a claim that this tests arbitrary real smoothness.
 *
 * The sample-based helper expects samples at z±h and z±ih in mathematical
 * complex coordinates.  It is suitable for a validation/diagnostic pass; an
 * analytic derivative path remains the preferred mathematical oracle.
 *
 * Target: Steam Deck RDNA2, Vulkan GLSL 4.60 → SPIR-V.
 */

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

    result.residual = vec2(du.x - dv.y, du.y + dv.x);
    result.residual_squared = dot(result.residual, result.residual);

    float derivative_energy = dot(du, du) + dot(dv, dv);
    float scale_squared = max(1.0, derivative_energy);
    float tolerance_squared = tolerance * tolerance * scale_squared;

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
    CauchyRiemannCheck result =
        cauchy_riemann_local_check(du, dv, tolerance, 0.0);
    return result.locally_complex_differentiable;
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
    CauchyRiemannCheck result = cauchy_riemann_local_check(
        du,
        dv,
        tolerance,
        derivative_floor
    );
    return result.conformal;
}
