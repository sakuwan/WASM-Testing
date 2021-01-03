;; WASM testing

(module
  (memory (export "memory") 1 1)

  ;; Since WASM SIMD lacks rcp, 1/a w/ a single Newton-Raphson iteration
  (type $_rcpNR1_t (func (param v128) (result v128)))
  (func $_rcpNR1 (type $_rcpNR1_t) (param $a v128) (result v128)
    (local $rcp v128)
    (local.set $rcp (f32x4.div (v128.const f32x4 1 1 1 1) (local.get $a)))
    (f32x4.mul ;; x_2(2 - a x_2)
      (local.get $rcp)
      (f32x4.sub
        (v128.const f32x4 2 2 2 2)
        (f32x4.mul (local.get $a) (local.get $rcp))
      )
    )
  )

  ;; JS-friendly RCP w/ single NR, since v128 will throw a TypeError as a parameter or return
  (type $rcpNR1_t (func (param f32 f32 f32 f32)))
  (func $rcpNR1 (type $rcpNR1_t) (param $x f32) (param $y f32) (param $z f32) (param $w f32)
    (v128.store
      (i32.const 0)
      (call $_rcpNR1 (call $_buildv128 (local.get $x) (local.get $y) (local.get $z) (local.get $w)))
    )
  )

  ;; f32x4 -> v128 conversion for JS interfacing
  ;; Maybe wzyx since most SIMD is reversed?
  (type $_builtv128_t (func (param f32 f32 f32 f32) (result v128)))
  (func $_buildv128 (type $_builtv128_t) (param $x f32) (param $y f32) (param $z f32) (param $w f32) (result v128)
    (v128.const i32x4 0 0 0 0)
    (f32x4.replace_lane 0 (local.get $x))
    (f32x4.replace_lane 1 (local.get $y))
    (f32x4.replace_lane 2 (local.get $z))
    (f32x4.replace_lane 3 (local.get $w))
  )

  (type $_sandwichPtT_t (func (param v128 v128) (result v128)))
  (func $_sandwhichPtT (type $_sandwichPtT_t) (param $p1 v128) (param $t1 v128) (result v128)
    (local $tmp v128)
    (local.set $tmp (f32x4.splat (f32x4.extract_lane 3 (local.get $p1))))
    (f32x4.add
      (local.get $p1)
      (f32x4.mul
        (v128.const f32x4 -2 -2 -2 0)
        (f32x4.mul
          (local.get $tmp)
          (local.get $t1)
        )
      )
    )
  )

  (type $sandwichPtT_t (func (param f32 f32 f32 f32 f32 f32 f32 f32)))
  (func $sandwichPtT (type $sandwichPtT_t) (param $a0 f32) (param $a1 f32) (param $a2 f32) (param $a3 f32)
                                           (param $b0 f32) (param $b1 f32) (param $b2 f32) (param $b3 f32)
    (v128.store
      (i32.const 0)
      (call $_sandwhichPtT
        (call $_buildv128 (local.get $a0) (local.get $a1) (local.get $a2) (local.get $a3))
        (call $_buildv128 (local.get $b0) (local.get $b1) (local.get $b2) (local.get $b3))
      )
    )
  )

  (type $_geometricPtPt_t (func (param v128 v128) (result v128)))
  (func $_geometricPtPt (type $_geometricPtPt_t) (param $p1 v128) (param $p2 v128) (result v128)
    (local $tmp v128)

    (local.set $tmp (f32x4.mul (f32x4.splat (f32x4.extract_lane 3 (local.get $p1))) (local.get $p2))) ;; t = p2(p1.e123)
    (local.set $tmp (f32x4.mul (local.get $tmp) (v128.const f32x4 -1 -1 -1 -2))) ;; t = t(-1, -1, -1, -2)
    (local.set $tmp ;; t = t + p1(p2.e123)
      (f32x4.add
        (local.get $tmp)
        (f32x4.mul
          (local.get $p1)
          (f32x4.splat (f32x4.extract_lane 3 (local.get $p2)))
        )
      )
    )

    (v128.and ;; out = (-1, -1, -1, 0) & (t(1/x - tmp.e123))
      (v128.const i32x4 -1 -1 -1 0)
      (f32x4.mul
        (local.get $tmp)
        (call $_rcpNR1 (f32x4.splat (f32x4.extract_lane 3 (local.get $tmp))))
      )
    )
  )

  (type $geometricPtPt_t (func (param f32 f32 f32 f32 f32 f32 f32 f32)))
  (func $geometricPtPt (type $geometricPtPt_t) (param $a0 f32) (param $a1 f32) (param $a2 f32) (param $a3 f32)
                                               (param $b0 f32) (param $b1 f32) (param $b2 f32) (param $b3 f32)
    (v128.store
      (i32.const 0)
      (call $_geometricPtPt
        (call $_buildv128 (local.get $a0) (local.get $a1) (local.get $a2) (local.get $a3))
        (call $_buildv128 (local.get $b0) (local.get $b1) (local.get $b2) (local.get $b3))
      )
    )
  )

  (export "rcpNR1" (func $rcpNR1))
  (export "sandwichPtT" (func $sandwichPtT))
  (export "geometricPtPt" (func $geometricPtPt))
)
