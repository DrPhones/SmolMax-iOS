#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Objective-C bridge wrapping llama.cpp inference engine and SmolMax Expert Pager for Swift
@interface LlamaBridge : NSObject

@property (nonatomic, readonly) BOOL isModelLoaded;
@property (nonatomic, readonly) BOOL isGenerating;
@property (nonatomic, readonly) double tokensPerSecond;
@property (nonatomic, readonly) double timeToFirstToken;
@property (nonatomic, readonly) double promptTokensPerSecond;
@property (nonatomic, readonly) double expertCacheHitRate;
@property (nonatomic, readonly) NSUInteger expertCacheHits;
@property (nonatomic, readonly) NSUInteger expertCacheMisses;
@property (nonatomic, readonly) NSUInteger storageReadsCount;
@property (nonatomic, readonly) double diskThroughputMBs;
@property (nonatomic, readonly) NSUInteger loadedExpertCount;

- (instancetype)init;

/// Load a GGUF model file with specified engine parameters
- (BOOL)loadModelWithPath:(NSString *)modelPath
              contextSize:(NSInteger)contextSize
                  threads:(NSInteger)threads
                   useGPU:(BOOL)useGPU
                    isMoE:(BOOL)isMoE
           expertPoolSize:(NSInteger)expertPoolSize
                    error:(NSError * _Nullable * _Nullable)error;

/// Unload currently loaded model and free all resources
- (void)unloadModel;

/// Generate text tokens for a given prompt with streaming callback
- (void)generateWithPrompt:(NSString *)prompt
               temperature:(float)temperature
                      topP:(float)topP
                      topK:(int)topK
             repeatPenalty:(float)repeatPenalty
                   onToken:(void (^)(NSString *piece))onToken
                onComplete:(void (^)(void))onComplete
                   onError:(void (^)(NSError *error))onError;

/// Stop current generation loop immediately
- (void)stopGeneration;

/// Clear KV cache to free memory
- (void)clearKVCache;

/// Update expert paging parameters dynamically
- (void)configureExpertPagingWithPoolSize:(NSInteger)poolSize
                          enablePrefetch:(BOOL)enablePrefetch
                             routingBias:(float)routingBias;

/// Notification when iOS triggers memory pressure warning
- (void)handleMemoryWarning;

@end

NS_ASSUME_NONNULL_END
