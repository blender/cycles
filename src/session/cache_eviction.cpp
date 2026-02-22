/* SPDX-FileCopyrightText: 2026 Blender Foundation
 *
 * SPDX-License-Identifier: Apache-2.0 */

#include "session/cache_eviction.h"

#include <chrono>

#include "util/math_base.h"
#include "util/time.h"

CCL_NAMESPACE_BEGIN

CacheEvictionManager::CacheEvictionManager(bool background) : background_(background) {}

void CacheEvictionManager::reset()
{
  render_tile_count_ = 0;
}

bool CacheEvictionManager::need_eviction(bool idle, bool switched_to_new_tile)
{
  /* Final render. */
  if (background_) {
    /* Evict before rendering the next tile, except the first one where we
     * can't determine what was shared with other tiles. */
    if (idle || !switched_to_new_tile) {
      return false;
    }

    render_tile_count_++;
    return render_tile_count_ >= 2;
  }

  /* Viewport render. */
  return false;
}

std::chrono::milliseconds CacheEvictionManager::wait_time(bool /*idle*/) const
{
  return std::chrono::milliseconds::max();
}

CCL_NAMESPACE_END
