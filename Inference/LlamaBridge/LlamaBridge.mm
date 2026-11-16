#import "LlamaBridge.h"
#include "ExpertPager.h"

// Standard llama.cpp C API definitions
#ifdef __cplusplus
extern "C" {
#endif

// Forward declarations of llama types for robust header decoupling
struct llama_model;
struct llama_context;
struct llama_vocab;
struct llama_sampler;

typedef int32_t llama_pos;
typedef int32_t llama_token;
typedef int32_t llama_seq_id;

struct llama_batch {
    int32_t n_tokens;
    llama_token * token;
    float * embd;
    llama_pos * pos;
    int32_t * n_seq_id;
    llama_seq_id ** seq_id;
    int8_t * logits;
};

struct llama_model_params {
    int32_t n_gpu_layers;
    int32_t main_gpu;
    const float * tensor_split;
    void * progress_callback;
    void * progress_callback_user_data;
    const void * kv_overrides;
    bool vocab_only;
    bool use_mmap;
    bool use_mlock;
    bool check_tensors;
};

struct llama_context_params {
    uint32_t n_ctx;
    uint32_t n_batch;
    uint32_t n_ubatch;
    uint32_t n_seq_max;
    int32_t n_threads;
    int32_t n_threads_batch;
    int8_t rope_scaling_type;
    int8_t pooling_type;
    int8_t attention_type;
    float rope_freq_base;
    float rope_freq_scale;
    float yarn_ext_factor;
    float yarn_attn_factor;
    float yarn_beta_fast;
    float yarn_beta_slow;
    uint32_t yarn_orig_ctx;
    float defrag_thold;
    void * cb_eval;
    void * cb_eval_user_data;
    enum { GGML_TYPE_F16 = 1, GGML_TYPE_Q8_0 = 8 } type_k;
    enum { GGML_TYPE_F16_V = 1 } type_v;
    bool logits_all;
    bool embeddings;
    bool offload_kqv;
    bool flash_attn;
    bool no_perf;
    void * abort_callback;
    void * abort_callback_data;
};

struct llama_sampler_chain_params {
    bool no_perf;
};

// API functions
void llama_backend_init(void);
void llama_backend_free(void);
struct llama_model_params llama_model_default_params(void);
struct llama_context_params llama_context_default_params(void);
struct llama_model * llama_model_load_from_file(const char * path_model, struct llama_model_params params);
void llama_model_free(struct llama_model * model);
const struct llama_vocab * llama_model_get_vocab(const struct llama_model * model);
struct llama_context * llama_init_from_model(struct llama_model * model, struct llama_context_params params);
void llama_free(struct llama_context * ctx);
void llama_kv_self_clear(struct llama_context * ctx);

int32_t llama_tokenize(const struct llama_vocab * vocab, const char * text, int32_t text_len, llama_token * tokens, int32_t n_tokens_max, bool add_special, bool parse_special);
int32_t llama_token_to_piece(const struct llama_vocab * vocab, llama_token token, char * buf, int32_t length, int32_t lstrip, bool special);
bool llama_vocab_is_eog(const struct llama_vocab * vocab, llama_token token);

struct llama_batch llama_batch_init(int32_t n_tokens, int32_t embd, int32_t n_seq_max);
void llama_batch_free(struct llama_batch batch);
int32_t llama_decode(struct llama_context * ctx, struct llama_batch batch);

struct llama_sampler_chain_params llama_sampler_chain_default_params(void);
struct llama_sampler * llama_sampler_chain_init(struct llama_sampler_chain_params params);
void llama_sampler_chain_add(struct llama_sampler * chain, struct llama_sampler * smpl);
struct llama_sampler * llama_sampler_init_top_k(int32_t k);
struct llama_sampler * llama_sampler_init_top_p(float p, size_t min_keep);
struct llama_sampler * llama_sampler_init_temp(float t);
struct llama_sampler * llama_sampler_init_dist(uint32_t seed);
struct llama_sampler * llama_sampler_init_greedy(void);
struct llama_sampler * llama_sampler_init_penalties(int32_t n_vocab, llama_token special_eos_id, llama_token linefeed_id, int32_t penalty_last_n, float penalty_repeat, float penalty_freq, float penalty_present, bool penalize_nl, bool ignore_eos);
llama_token llama_sampler_sample(struct llama_sampler * smpl, struct llama_context * ctx, int32_t idx);
void llama_sampler_accept(struct llama_sampler * smpl, llama_token token);
void llama_sampler_free(struct llama_sampler * smpl);

#ifdef __cplusplus
}
#endif

@interface LlamaBridge () {
    struct llama_model * _model;
    struct llama_context * _ctx;
    const struct llama_vocab * _vocab;
    std::unique_ptr<smolmax::ExpertPager> _expertPager;
    std::atomic<bool> _stopRequested;
    std::atomic<bool> _isGeneratingAtomic;
    uint64_t _stepCounter;
}

@property (nonatomic, assign) BOOL isModelLoaded;
@property (nonatomic, assign) double tokensPerSecond;
@property (nonatomic, assign) double timeToFirstToken;
@property (nonatomic, assign) double promptTokensPerSecond;

@end

@implementation LlamaBridge

- (instancetype)init {
    self = [super init];
    if (self) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            llama_backend_init();
        });
        _model = nullptr;
        _ctx = nullptr;
        _vocab = nullptr;
        _expertPager = std::make_unique<smolmax::ExpertPager>();
        _stopRequested = false;
        _isGeneratingAtomic = false;
        _stepCounter = 0;
        _isModelLoaded = NO;
        _tokensPerSecond = 0.0;
        _timeToFirstToken = 0.0;
        _promptTokensPerSecond = 0.0;
    }
    return self;
}

- (void)dealloc {
    [self unloadModel];
}

- (BOOL)isGenerating {
    return _isGeneratingAtomic.load();
}

- (double)expertCacheHitRate {
    return _expertPager ? _expertPager->get_cache_hit_rate() : 0.0;
}

- (NSUInteger)expertCacheHits {
    return _expertPager ? (NSUInteger)_expertPager->get_cache_hits() : 0;
}

- (NSUInteger)expertCacheMisses {
    return _expertPager ? (NSUInteger)_expertPager->get_cache_misses() : 0;
}

- (NSUInteger)storageReadsCount {
    return _expertPager ? (NSUInteger)_expertPager->get_storage_reads() : 0;
}

- (double)diskThroughputMBs {
    return _expertPager ? _expertPager->get_disk_throughput_mb_s() : 0.0;
}

- (NSUInteger)loadedExpertCount {
    return _expertPager ? (NSUInteger)_expertPager->get_active_expert_count() : 0;
}

- (BOOL)loadModelWithPath:(NSString *)modelPath
              contextSize:(NSInteger)contextSize
                  threads:(NSInteger)threads
                   useGPU:(BOOL)useGPU
                    isMoE:(BOOL)isMoE
           expertPoolSize:(NSInteger)expertPoolSize
                    error:(NSError * _Nullable *)error {
    [self unloadModel];

    std::string pathStr = [modelPath UTF8String];

    // Model parameters
    struct llama_model_params model_params = llama_model_default_params();
    model_params.use_mmap = true; // Essential: lazy page-in
    model_params.use_mlock = false; // NEVER on iOS (causes jetsam kill)
    model_params.n_gpu_layers = useGPU ? 99 : 0;

    _model = llama_model_load_from_file(pathStr.c_str(), model_params);
    if (!_model) {
        if (error) {
            *error = [NSError errorWithDomain:@"SmolMax.Engine"
                                         code:101
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to load model from GGUF file"}];
        }
        return NO;
    }

    _vocab = llama_model_get_vocab(_model);

    // Context parameters
    struct llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = (uint32_t)contextSize;
    ctx_params.n_threads = (int32_t)threads;
    ctx_params.n_threads_batch = (int32_t)threads;

    _ctx = llama_init_from_model(_model, ctx_params);
    if (!_ctx) {
        llama_model_free(_model);
        _model = nullptr;
        _vocab = nullptr;
        if (error) {
            *error = [NSError errorWithDomain:@"SmolMax.Engine"
                                         code:102
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to create llama context"}];
        }
        return NO;
    }

    // Initialize Expert Pager if MoE model
    if (isMoE) {
        size_t poolSize = (expertPoolSize > 0) ? (size_t)expertPoolSize : 6;
        size_t approxExpertBytes = 16 * 1024 * 1024; // 16MB per expert slab
        _expertPager->setup(pathStr, 32, 32, 2, poolSize, approxExpertBytes);
    }

    self.isModelLoaded = YES;
    return YES;
}

- (void)unloadModel {
    if (_ctx) {
        llama_free(_ctx);
        _ctx = nullptr;
    }
    if (_model) {
        llama_model_free(_model);
        _model = nullptr;
    }
    _vocab = nullptr;
    self.isModelLoaded = NO;
}

- (void)generateWithPrompt:(NSString *)prompt
               temperature:(float)temperature
                      topP:(float)topP
                      topK:(int)topK
             repeatPenalty:(float)repeatPenalty
                   onToken:(void (^)(NSString *piece))onToken
                onComplete:(void (^)(void))onComplete
                   onError:(void (^)(NSError *error))onError {
    if (!_ctx || !_model || !_vocab) {
        if (onError) {
            onError([NSError errorWithDomain:@"SmolMax.Engine" code:100 userInfo:@{NSLocalizedDescriptionKey: @"No model loaded"}]);
        }
        return;
    }

    _stopRequested = false;
    _isGeneratingAtomic = true;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_USER_INITIATED, 0), ^{
        std::string promptStr = [prompt UTF8String];

        // 1. Tokenize prompt
        int32_t n_tokens_max = (int32_t)promptStr.length() + 16;
        std::vector<llama_token> prompt_tokens(n_tokens_max);
        int32_t n_prompt_tokens = llama_tokenize(_vocab, promptStr.c_str(), (int32_t)promptStr.length(), prompt_tokens.data(), n_tokens_max, true, true);
        if (n_prompt_tokens < 0) {
            prompt_tokens.resize(-n_prompt_tokens);
            n_prompt_tokens = llama_tokenize(_vocab, promptStr.c_str(), (int32_t)promptStr.length(), prompt_tokens.data(), (int32_t)prompt_tokens.size(), true, true);
        } else {
            prompt_tokens.resize(n_prompt_tokens);
        }

        // 2. Setup sampler chain
        struct llama_sampler_chain_params sparams = llama_sampler_chain_default_params();
        struct llama_sampler * smpl = llama_sampler_chain_init(sparams);
        llama_sampler_chain_add(smpl, llama_sampler_init_top_k(topK));
        llama_sampler_chain_add(smpl, llama_sampler_init_top_p(topP, 1));
        llama_sampler_chain_add(smpl, llama_sampler_init_temp(temperature));
        llama_sampler_chain_add(smpl, llama_sampler_init_dist(1337));

        // 3. Evaluate prompt batch
        auto prompt_start = std::chrono::high_resolution_clock::now();
        struct llama_batch batch = llama_batch_init((int32_t)prompt_tokens.size(), 0, 1);
        for (size_t i = 0; i < prompt_tokens.size(); ++i) {
            batch.token[i] = prompt_tokens[i];
            batch.pos[i] = (llama_pos)i;
            batch.n_seq_id[i] = 1;
            batch.seq_id[i][0] = 0;
            batch.logits[i] = (i == prompt_tokens.size() - 1); // Only need logits for the last token
        }
        batch.n_tokens = (int32_t)prompt_tokens.size();

        if (llama_decode(self->_ctx, batch) != 0) {
            llama_batch_free(batch);
            llama_sampler_free(smpl);
            self->_isGeneratingAtomic = false;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (onError) onError([NSError errorWithDomain:@"SmolMax.Engine" code:103 userInfo:@{NSLocalizedDescriptionKey: @"Prompt evaluation failed"}]);
            });
            return;
        }

        auto prompt_end = std::chrono::high_resolution_clock::now();
        std::chrono::duration<double> prompt_duration = prompt_end - prompt_start;
        if (prompt_duration.count() > 0) {
            self.promptTokensPerSecond = (double)prompt_tokens.size() / prompt_duration.count();
        }

        llama_batch_free(batch);

        // 4. Generation loop
        int32_t n_cur = (int32_t)prompt_tokens.size();
        int32_t n_decode = 0;
        auto gen_start = std::chrono::high_resolution_clock::now();
        bool firstTokenEmitted = false;

        struct llama_batch gen_batch = llama_batch_init(1, 0, 1);

        while (!self->_stopRequested.load()) {
            // Sample next token
            llama_token new_token_id = llama_sampler_sample(smpl, self->_ctx, -1);
            llama_sampler_accept(smpl, new_token_id);

            // Check End-of-Generation
            if (llama_vocab_is_eog(self->_vocab, new_token_id)) {
                break;
            }

            // Convert token to piece
            char piece_buf[256];
            int n_chars = llama_token_to_piece(self->_vocab, new_token_id, piece_buf, sizeof(piece_buf), 0, false);
            if (n_chars > 0) {
                NSString *piece = [[NSString alloc] initWithBytes:piece_buf length:n_chars encoding:NSUTF8StringEncoding];
                if (piece) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (onToken) onToken(piece);
                    });
                }
            }

            if (!firstTokenEmitted) {
                auto first_token_time = std::chrono::high_resolution_clock::now();
                std::chrono::duration<double> ttft = first_token_time - prompt_start;
                self.timeToFirstToken = ttft.count();
                firstTokenEmitted = true;
            }

            n_decode++;
            self->_stepCounter++;

            // Decode next single token
            gen_batch.token[0] = new_token_id;
            gen_batch.pos[0] = (llama_pos)n_cur;
            gen_batch.n_seq_id[0] = 1;
            gen_batch.seq_id[0][0] = 0;
            gen_batch.logits[0] = true;
            gen_batch.n_tokens = 1;

            if (llama_decode(self->_ctx, gen_batch) != 0) {
                break;
            }

            n_cur++;
        }

        auto gen_end = std::chrono::high_resolution_clock::now();
        std::chrono::duration<double> gen_duration = gen_end - gen_start;
        if (gen_duration.count() > 0 && n_decode > 0) {
            self.tokensPerSecond = (double)n_decode / gen_duration.count();
        }

        llama_batch_free(gen_batch);
        llama_sampler_free(smpl);
        self->_isGeneratingAtomic = false;

        dispatch_async(dispatch_get_main_queue(), ^{
            if (onComplete) onComplete();
        });
    });
}

- (void)stopGeneration {
    _stopRequested = true;
}

- (void)clearKVCache {
    if (_ctx) {
        llama_kv_self_clear(_ctx);
    }
}

- (void)configureExpertPagingWithPoolSize:(NSInteger)poolSize
                          enablePrefetch:(BOOL)enablePrefetch
                             routingBias:(float)routingBias {
    if (_expertPager) {
        _expertPager->set_prefetch_enabled(enablePrefetch);
        _expertPager->set_routing_bias(routingBias);
    }
}

- (void)handleMemoryWarning {
    if (_expertPager) {
        _expertPager->on_memory_pressure_warning();
    }
    [self clearKVCache];
}

@end
