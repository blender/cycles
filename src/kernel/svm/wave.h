/* SPDX-FileCopyrightText: 2011-2022 Blender Foundation
 *
 * SPDX-License-Identifier: Apache-2.0 */

#pragma once

#include "kernel/svm/fractal_noise.h"
#include "kernel/svm/node_types.h"
#include "kernel/svm/util.h"

CCL_NAMESPACE_BEGIN

/* Wave */

ccl_device_noinline_cpu float svm_wave(NodeWaveType type,
                                       NodeWaveBandsDirection bands_dir,
                                       NodeWaveRingsDirection rings_dir,
                                       NodeWaveProfile profile,
                                       float3 p,
                                       const float distortion,
                                       const float detail,
                                       const float dscale,
                                       const float droughness,
                                       const float phase)
{
  /* Prevent precision issues on unit coordinates. */
  p = (p + 0.000001f) * 0.999999f;

  float n;

  if (type == NODE_WAVE_BANDS) {
    if (bands_dir == NODE_WAVE_BANDS_DIRECTION_X) {
      n = p.x * 20.0f;
    }
    else if (bands_dir == NODE_WAVE_BANDS_DIRECTION_Y) {
      n = p.y * 20.0f;
    }
    else if (bands_dir == NODE_WAVE_BANDS_DIRECTION_Z) {
      n = p.z * 20.0f;
    }
    else { /* NODE_WAVE_BANDS_DIRECTION_DIAGONAL */
      n = (p.x + p.y + p.z) * 10.0f;
    }
  }
  else { /* NODE_WAVE_RINGS */
    float3 rp = p;
    if (rings_dir == NODE_WAVE_RINGS_DIRECTION_X) {
      rp *= make_float3(0.0f, 1.0f, 1.0f);
    }
    else if (rings_dir == NODE_WAVE_RINGS_DIRECTION_Y) {
      rp *= make_float3(1.0f, 0.0f, 1.0f);
    }
    else if (rings_dir == NODE_WAVE_RINGS_DIRECTION_Z) {
      rp *= make_float3(1.0f, 1.0f, 0.0f);
    }
    /* else: NODE_WAVE_RINGS_DIRECTION_SPHERICAL */

    n = len(rp) * 20.0f;
  }

  n += phase;

  if (distortion != 0.0f) {
    n += distortion * (noise_fbm(p * dscale, detail, droughness, 2.0f, true) * 2.0f - 1.0f);
  }

  if (profile == NODE_WAVE_PROFILE_SIN) {
    return 0.5f + 0.5f * sinf(n - M_PI_2_F);
  }
  if (profile == NODE_WAVE_PROFILE_SAW) {
    n /= M_2PI_F;
    return n - floorf(n);
  }
  /* NODE_WAVE_PROFILE_TRI */
  n /= M_2PI_F;
  return fabsf(n - floorf(n + 0.5f)) * 2.0f;
}

ccl_device_noinline void svm_node_tex_wave(ccl_private float *ccl_restrict stack,
                                           const ccl_global SVMNodeTexWave &ccl_restrict node)
{
  const float3 co = stack_load_float3(stack, node.co);
  const float scale = stack_load(stack, node.scale);
  const float distortion = stack_load(stack, node.distortion);
  const float detail = stack_load(stack, node.detail);
  const float dscale = stack_load(stack, node.dscale);
  const float droughness = stack_load(stack, node.droughness);
  const float phase = stack_load(stack, node.phase);

  const float f = svm_wave(node.wave_type,
                           node.bands_direction,
                           node.rings_direction,
                           node.profile,
                           co * scale,
                           distortion,
                           detail,
                           dscale,
                           droughness,
                           phase);

  if (stack_valid(node.fac_offset)) {
    stack_store_float(stack, node.fac_offset, f);
  }
  if (stack_valid(node.color_offset)) {
    stack_store_float3(stack, node.color_offset, make_float3(f, f, f));
  }
}

CCL_NAMESPACE_END
