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
 * The residual is (u_x - v_y, u_y + v_x). A small residual is the local
 * Cauchy–Riemann numerical check. `check_conformal` additionally requires a
 * nonzero complex derivative. The smoothness names are vocabulary aliases,
 * not a claim that this tests arbitrary real smoothness.
 *
 * The sample-based helper expects samples at z±h and z±ih in mathematical
 * complex coordinates. It deliberately does not use screen-space dpdx/dpdy.
 *
 * Target: WebGPU / WGSL.
 */

struct CauchyRiemannCheck {
    residual: vec2<f32>,
    residual_squared: f32,
    derivative_squared: f32,
    locally_complex_differentiable: bool,
    conformal: bool,
}

fn cauchy_riemann_local_check(
    du: vec2<f32>,
    dv: vec2<f32>,
    tolerance: f32,
    derivative_floor: f32,
) -> CauchyRiemannCheck {
    let residual = vec2<f32>(
        du.x - dv.y,
        du.y + dv.x,
    );
    let residual_squared = dot(residual, residual);

    let derivative_energy = dot(du, du) + dot(dv, dv);
    let scale_squared = max(1.0, derivative_energy);
    let tolerance_squared = tolerance * tolerance * scale_squared;

    let derivative_squared = du.x * du.x + dv.x * dv.x;
    let locally_complex_differentiable =
        residual_squared <= tolerance_squared;
    let conformal =
        locally_complex_differentiable &&
        derivative_squared > derivative_floor * derivative_floor;

    return CauchyRiemannCheck(
        residual,
        residual_squared,
        derivative_squared,
        locally_complex_differentiable,
        conformal,
    );
}

fn cauchy_riemann_from_samples(
    f_x_minus: vec2<f32>,
    f_x_plus: vec2<f32>,
    f_y_minus: vec2<f32>,
    f_y_plus: vec2<f32>,
    step: f32,
    tolerance: f32,
    derivative_floor: f32,
) -> CauchyRiemannCheck {
    let inverse_span = 0.5 / max(abs(step), 1.0e-12);
    let dfdx = (f_x_plus - f_x_minus) * inverse_span;
    let dfdy = (f_y_plus - f_y_minus) * inverse_span;

    let du = vec2<f32>(dfdx.x, dfdy.x);
    let dv = vec2<f32>(dfdx.y, dfdy.y);

    return cauchy_riemann_local_check(
        du,
        dv,
        tolerance,
        derivative_floor,
    );
}

fn check_holomorphic(
    du: vec2<f32>,
    dv: vec2<f32>,
    tolerance: f32,
) -> bool {
    let result = cauchy_riemann_local_check(du, dv, tolerance, 0.0);
    return result.locally_complex_differentiable;
}

fn check_smooth(
    du: vec2<f32>,
    dv: vec2<f32>,
    tolerance: f32,
) -> bool {
    return check_holomorphic(du, dv, tolerance);
}

fn check_local_smoothness(
    du: vec2<f32>,
    dv: vec2<f32>,
    tolerance: f32,
) -> bool {
    return check_holomorphic(du, dv, tolerance);
}

fn check_conformal(
    du: vec2<f32>,
    dv: vec2<f32>,
    tolerance: f32,
    derivative_floor: f32,
) -> bool {
    let result = cauchy_riemann_local_check(
        du,
        dv,
        tolerance,
        derivative_floor,
    );
    return result.conformal;
}
