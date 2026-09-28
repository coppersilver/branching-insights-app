#ifndef API_CLIENT_H
#define API_CLIENT_H

#ifdef __cplusplus
extern "C" {
#endif

// Data structure to hold the insight and branching ideas
// All char pointers are dynamically allocated and must be freed by the receiver
typedef struct {
    char *main_insight;
    char *branch_titles[3];
    char *branch_stems[3];
} InsightData;

// Callback function type
typedef void (*InsightCallback)(InsightData *result);

// Main function to fetch insight
// topic: Optional user topic (can be NULL)
// previous_insight: Optional previous insight text to avoid repetition (can be NULL)
// prompt_stem: Optional specific prompt for branching (can be NULL. If present, overrides topic/previous)
// callback: Function to call with the result
void fetchInsight(const char *topic, const char *previous_insight, const char *prompt_stem, InsightCallback callback);

// Helper to free the InsightData contents
void freeInsightData(InsightData *data);

#ifdef __cplusplus
}
#endif

#endif
