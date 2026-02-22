/* SPDX-FileCopyrightText: 2026 Blender Foundation
 *
 * SPDX-License-Identifier: Apache-2.0 */

#pragma once

#include <chrono>

#include "util/types.h"

CCL_NAMESPACE_BEGIN

/* CacheEvictionManager has decides when texture cache eviction should
 * happen in a render session. */
class CacheEvictionManager {
 public:
  explicit CacheEvictionManager(bool background);

  /* Reset state when starting a new render. */
  void reset();

  /* For a render iteration, check if cache eviction is needed. */
  bool need_eviction(bool idle, bool switched_to_new_tile);

  /* Wait time until cache eviction needs to be performed. */
  std::chrono::milliseconds wait_time(bool idle) const;

 private:
  const bool background_;

  int render_tile_count_ = 0;
};

CCL_NAMESPACE_END
