/* SPDX-FileCopyrightText: 2011-2022 Blender Foundation
 *
 * SPDX-License-Identifier: Apache-2.0 */

#pragma once

#include "kernel/svm/node_types.h"
#include "kernel/svm/util.h"

CCL_NAMESPACE_BEGIN

/* Map Range Node */

ccl_device_inline float smootherstep(const float edge0, const float edge1, float x)
{
  x = clamp(safe_divide((x - edge0), (edge1 - edge0)), 0.0f, 1.0f);
  return x * x * x * (x * (x * 6.0f - 15.0f) + 10.0f);
}

ccl_device_noinline void svm_node_map_range(ccl_private float *ccl_restrict stack,
                                            const ccl_global SVMNodeMapRange &ccl_restrict node)
{
  const float value = stack_load(stack, node.value);
  const float from_min = stack_load(stack, node.from_min);
  const float from_max = stack_load(stack, node.from_max);
  const float to_min = stack_load(stack, node.to_min);
  const float to_max = stack_load(stack, node.to_max);
  const float steps = stack_load(stack, node.steps);

  float result;

  if (from_max != from_min) {
    float factor = value;
    switch (node.range_type) {
      default:
      case NODE_MAP_RANGE_LINEAR:
        factor = (value - from_min) / (from_max - from_min);
        break;
      case NODE_MAP_RANGE_STEPPED: {
        factor = (value - from_min) / (from_max - from_min);
        factor = (steps > 0.0f) ? floorf(factor * (steps + 1.0f)) / steps : 0.0f;
        break;
      }
      case NODE_MAP_RANGE_SMOOTHSTEP: {
        factor = (from_min > from_max) ? 1.0f - smoothstep(from_max, from_min, factor) :
                                         smoothstep(from_min, from_max, factor);
        break;
      }
      case NODE_MAP_RANGE_SMOOTHERSTEP: {
        factor = (from_min > from_max) ? 1.0f - smootherstep(from_max, from_min, factor) :
                                         smootherstep(from_min, from_max, factor);
        break;
      }
    }
    result = to_min + factor * (to_max - to_min);
  }
  else {
    result = 0.0f;
  }
  stack_store_float(stack, node.result_offset, result);
}

ccl_device_noinline void svm_node_vector_map_range(
    ccl_private float *ccl_restrict stack,
    const ccl_global SVMNodeVectorMapRange &ccl_restrict node)
{
  const float3 value = stack_load(stack, node.value);
  const float3 from_min = stack_load(stack, node.from_min);
  const float3 from_max = stack_load(stack, node.from_max);
  const float3 to_min = stack_load(stack, node.to_min);
  const float3 to_max = stack_load(stack, node.to_max);
  const float3 steps = stack_load(stack, node.steps);

  const int use_clamp = (node.range_type == NODE_MAP_RANGE_SMOOTHSTEP ||
                         node.range_type == NODE_MAP_RANGE_SMOOTHERSTEP) ?
                            0 :
                            node.use_clamp;
  float3 result;
  float3 factor = value;
  switch (node.range_type) {
    default:
    case NODE_MAP_RANGE_LINEAR:
      factor = safe_divide((value - from_min), (from_max - from_min));
      break;
    case NODE_MAP_RANGE_STEPPED: {
      factor = safe_divide((value - from_min), (from_max - from_min));
      factor = make_float3((steps.x > 0.0f) ? floorf(factor.x * (steps.x + 1.0f)) / steps.x : 0.0f,
                           (steps.y > 0.0f) ? floorf(factor.y * (steps.y + 1.0f)) / steps.y : 0.0f,
                           (steps.z > 0.0f) ? floorf(factor.z * (steps.z + 1.0f)) / steps.z :
                                              0.0f);
      break;
    }
    case NODE_MAP_RANGE_SMOOTHSTEP: {
      factor = safe_divide((value - from_min), (from_max - from_min));
      factor = clamp(factor, zero_float3(), one_float3());
      factor = (make_float3(3.0f, 3.0f, 3.0f) - 2.0f * factor) * (factor * factor);
      break;
    }
    case NODE_MAP_RANGE_SMOOTHERSTEP: {
      factor = safe_divide((value - from_min), (from_max - from_min));
      factor = clamp(factor, zero_float3(), one_float3());
      factor = factor * factor * factor * (factor * (factor * 6.0f - 15.0f) + 10.0f);
      break;
    }
  }
  result = to_min + factor * (to_max - to_min);
  if (use_clamp > 0) {
    result.x = (to_min.x > to_max.x) ? clamp(result.x, to_max.x, to_min.x) :
                                       clamp(result.x, to_min.x, to_max.x);
    result.y = (to_min.y > to_max.y) ? clamp(result.y, to_max.y, to_min.y) :
                                       clamp(result.y, to_min.y, to_max.y);
    result.z = (to_min.z > to_max.z) ? clamp(result.z, to_max.z, to_min.z) :
                                       clamp(result.z, to_min.z, to_max.z);
  }

  stack_store_float3(stack, node.result_offset, result);
}

CCL_NAMESPACE_END
