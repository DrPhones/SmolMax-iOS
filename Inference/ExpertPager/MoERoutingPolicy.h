#ifndef SMOLMAX_MOE_ROUTING_POLICY_H
#define SMOLMAX_MOE_ROUTING_POLICY_H

#include <vector>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <functional>

namespace smolmax {

struct RoutedExpert {
    int32_t expert_id;
    float weight;
};

/// Flexible MoE Router supporting exact top-K and optional cache-aware routing bias
class MoERoutingPolicy {
public:
    /**
     * Compute top-K active experts for a given token.
     * 
     * @param logits Raw router output logits for all experts [num_experts]
     * @param num_experts Total number of experts in this layer
     * @param top_k Number of active experts per token (e.g. 2 for Ling-mini, or variable for Qwen3-Next)
     * @param is_cached_fn Predicate function returning true if expert_id is currently resident in RAM cache
     * @param cache_bias Optional bias added to logits for resident experts (0.0 = exact routing)
     * @return List of selected experts sorted by weight with normalized softmax probabilities
     */
    static std::vector<RoutedExpert> select_experts(
        const float* logits,
        int32_t num_experts,
        int32_t top_k,
        const std::function<bool(int32_t)>& is_cached_fn,
        float cache_bias = 0.0f
    ) {
        if (!logits || num_experts <= 0 || top_k <= 0) {
            return {};
        }

        top_k = std::min(top_k, num_experts);

        std::vector<std::pair<float, int32_t>> scored_experts(num_experts);

        // 1. Calculate biased logits (if bias > 0)
        for (int32_t i = 0; i < num_experts; ++i) {
            float score = logits[i];
            if (cache_bias > 0.0f && is_cached_fn && is_cached_fn(i)) {
                score += cache_bias;
            }
            scored_experts[i] = {score, i};
        }

        // 2. Select top-K
        std::partial_sort(
            scored_experts.begin(),
            scored_experts.begin() + top_k,
            scored_experts.end(),
            [](const std::pair<float, int32_t>& a, const std::pair<float, int32_t>& b) {
                return a.first > b.first;
            }
        );

        // 3. Compute Softmax normalization over the top-K selected experts
        float max_score = scored_experts[0].first;
        float sum_exp = 0.0f;
        std::vector<float> exp_scores(top_k);

        for (int32_t k = 0; k < top_k; ++k) {
            exp_scores[k] = std::exp(scored_experts[k].first - max_score);
            sum_exp += exp_scores[k];
        }

        std::vector<RoutedExpert> results(top_k);
        for (int32_t k = 0; k < top_k; ++k) {
            results[k] = {
                scored_experts[k].second,
                sum_exp > 0.0f ? (exp_scores[k] / sum_exp) : (1.0f / top_k)
            };
        }

        return results;
    }
};

} // namespace smolmax

#endif // SMOLMAX_MOE_ROUTING_POLICY_H
