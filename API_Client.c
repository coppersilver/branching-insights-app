#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <curl/curl.h>
#include "cJSON.h"
#include "API_Client.h"

// Hardcoded API Key (Ideally this should be passed in or loaded securely)
static const char *OPENROUTER_API_KEY = "sk-or-placeholder";
static const char *OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";

// Helper struct for CURL response
struct MemoryStruct {
    char *memory;
    size_t size;
};

static size_t WriteMemoryCallback(void *contents, size_t size, size_t nmemb, void *userp) {
    size_t realsize = size * nmemb;
    struct MemoryStruct *mem = (struct MemoryStruct *)userp;
    
    char *ptr = realloc(mem->memory, mem->size + realsize + 1);
    if(!ptr) {
        printf("not enough memory (realloc returned NULL)\n");
        return 0;
    }
    
    mem->memory = ptr;
    memcpy(&(mem->memory[mem->size]), contents, realsize);
    mem->size += realsize;
    mem->memory[mem->size] = 0;
    
    return realsize;
}

// Helper to sanitize JSON string (remove markdown code blocks)
// Returns a pointer to the start of valid JSON in the buffer
// Does NOT allocate new memory, modifies/returns pointer within existing buffer if needed.
static char* sanitize_json(char *input) {
    if (!input) return NULL;
    char *p = input;
    // Skip whitespace
    while (*p && (*p == ' ' || *p == '\n' || *p == '\r' || *p == '\t')) p++;
    
    if (strncmp(p, "```json", 7) == 0) {
        p += 7;
    } else if (strncmp(p, "```", 3) == 0) {
        p += 3;
    }
    
    // We also need to trim trailing ``` if present, acts destructively
    char *end = p + strlen(p) - 1;
    while (end > p && (*end == ' ' || *end == '\n' || *end == '\r' || *end == '\t')) end--;
    if (end > p && *end == '`') {
        // Assume at least 3
        if (*(end-1) == '`' && *(end-2) == '`') {
            *(end-2) = '\0';
        }
    }
    return p;
}

void fetchInsight(const char *topic, const char *previous_insight, const char *prompt_stem, InsightCallback callback) {
    CURL *curl;
    CURLcode res;
    struct MemoryStruct chunk;
    chunk.memory = malloc(1);
    chunk.size = 0;
    
    // Prepare a safe error result by default
    InsightData result = {0};
    result.main_insight = "Error: An unknown error occurred.";
    
    curl = curl_easy_init();
    if (!curl) {
        if (chunk.memory) free(chunk.memory);
        result.main_insight = "Error: Failed to initialize network engine.";
        if (callback) callback(&result);
        return;
    }
    
    // 1. Build Prompt
    char *systemInstruction = "You are a profound insight generator. You must return ONLY strictly valid JSON with no markdown formatting. "
                              "The branching ideas must be distinct logical extensions or questions based ONLY on the specific concepts in the 'main_insight' you generate, strictly ignoring the original topic context. "
                              "The JSON schema is: { \"main_insight\": \"string\", \"branching_ideas\": [ { \"title\": \"string (max 140 chars, written like an spontaneous and reflective personal thought in a clear but intelligent style. Avoid academic jargon.)\", \"prompt_stem\": \"string (full detailed prompt for this branch: must remain detailed and technically sound)\" }, ... 3 items ] }";
    
    char userMessage[2048]; // Safe buffer size for prompt construction
    if (prompt_stem && strlen(prompt_stem) > 0) {
        snprintf(userMessage, sizeof(userMessage), "%s", prompt_stem);
    } else {
        const char *basePrompt = "Give me a profound PHD level psychological or philosophical insight. Keep it concise (2-3 sentences).";
        if (topic && strlen(topic) > 0) {
            char temp[1024];
            snprintf(temp, sizeof(temp), "Topic: %s. %s", topic, basePrompt);
            // Append context check
            if (previous_insight && strlen(previous_insight) > 0) {
                 snprintf(userMessage, sizeof(userMessage), "%s Do not repeat this previous insight: \"%s\"", temp, previous_insight);
            } else {
                 snprintf(userMessage, sizeof(userMessage), "%s", temp);
            }
        } else {
            // Default
            if (previous_insight && strlen(previous_insight) > 0) {
                snprintf(userMessage, sizeof(userMessage), "%s Do not repeat this previous insight: \"%s\"", basePrompt, previous_insight);
            } else {
                snprintf(userMessage, sizeof(userMessage), "%s", basePrompt);
            }
        }
    }
    
    // 2. Build JSON Payload using cJSON
    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "model", "tngtech/deepseek-r1t2-chimera:free");
    cJSON_AddNumberToObject(root, "temperature", 0.7);
    cJSON *messages = cJSON_CreateArray();
    cJSON_AddItemToObject(root, "messages", messages);
    
    cJSON *sysMsg = cJSON_CreateObject();
    cJSON_AddStringToObject(sysMsg, "role", "system");
    cJSON_AddStringToObject(sysMsg, "content", systemInstruction);
    cJSON_AddItemToArray(messages, sysMsg);
    
    cJSON *usrMsg = cJSON_CreateObject();
    cJSON_AddStringToObject(usrMsg, "role", "user");
    cJSON_AddStringToObject(usrMsg, "content", userMessage);
    cJSON_AddItemToArray(messages, usrMsg);
    
    char *jsonString = cJSON_PrintUnformatted(root);
    
    // 3. Setup CURL
    struct curl_slist *headers = NULL;
    headers = curl_slist_append(headers, "Content-Type: application/json");
    char authHeader[256];
    snprintf(authHeader, sizeof(authHeader), "Authorization: Bearer %s", OPENROUTER_API_KEY);
    headers = curl_slist_append(headers, authHeader);
    headers = curl_slist_append(headers, "HTTP-Referer: https://github.com/google/antigravity");
    headers = curl_slist_append(headers, "X-Title: OpenRouter Insight App");
    
    curl_easy_setopt(curl, CURLOPT_URL, OPENROUTER_URL);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, jsonString);
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteMemoryCallback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, (void *)&chunk);
    
    res = curl_easy_perform(curl);
    
    int success = 0;
    
    if (res == CURLE_OK) {
        long response_code;
        curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &response_code);
        if (response_code == 200) {
             // 4. Parse Response
             cJSON *responseParams = cJSON_Parse(chunk.memory);
             if (responseParams) {
                 cJSON *choices = cJSON_GetObjectItem(responseParams, "choices");
                 if (cJSON_IsArray(choices) && cJSON_GetArraySize(choices) > 0) {
                     cJSON *choice = cJSON_GetArrayItem(choices, 0);
                     cJSON *message = cJSON_GetObjectItem(choice, "message");
                     cJSON *content = cJSON_GetObjectItem(message, "content");
                     
                     if (cJSON_IsString(content) && content->valuestring) {
                         char *cleanContent = sanitize_json(content->valuestring);
                         
                         // Double parse inner JSON
                         cJSON *innerParams = cJSON_Parse(cleanContent);
                         if (innerParams) {
                             // SUCCESS PATH
                             success = 1;
                             
                             result.main_insight = "No insight found."; // Fallback
                             cJSON *mainInsight = cJSON_GetObjectItem(innerParams, "main_insight");
                             if (cJSON_IsString(mainInsight)) {
                                 result.main_insight = mainInsight->valuestring;
                             } else {
                                 result.main_insight = cleanContent;
                             }
                             
                             cJSON *branches = cJSON_GetObjectItem(innerParams, "branching_ideas");
                             if (cJSON_IsArray(branches)) {
                                 int count = cJSON_GetArraySize(branches);
                                 if (count > 3) count = 3;
                                 for (int i=0; i<count; i++) {
                                     cJSON *b = cJSON_GetArrayItem(branches, i);
                                     cJSON *title = cJSON_GetObjectItem(b, "title");
                                     cJSON *stem = cJSON_GetObjectItem(b, "prompt_stem");
                                     if (cJSON_IsString(title)) result.branch_titles[i] = title->valuestring;
                                     if (cJSON_IsString(stem)) result.branch_stems[i] = stem->valuestring;
                                 }
                             }
                             
                             if (callback) callback(&result);
                             cJSON_Delete(innerParams);
                         } else {
                             // Fallback: Failed to parse inner JSON
                             success = 1;
                             result.main_insight = cleanContent;
                             if (callback) callback(&result);
                         }
                     } else {
                         result.main_insight = "Error: Invalid API response format (missing content).";
                     }
                 } else {
                     result.main_insight = "Error: Invalid API response format (missing choices).";
                 }
                 cJSON_Delete(responseParams);
             } else {
                 result.main_insight = "Error: Response was not valid JSON.";
             }
        } else {
            char errorBuf[128];
            snprintf(errorBuf, sizeof(errorBuf), "Error: API returned HTTP %ld", response_code);
            result.main_insight = errorBuf; // Note: Points to stack buffer, risky if callback is async, but callback is sync here.
                                            // Better: use static error literal or heap.
                                            // Actually, stack buffer 'errorBuf' is fine because 'callback' is called synchronously right now.
                                            // To be mostly safe, let's use a simpler static string or just the buffer if we trust the callback.
                                            // The callback copies the string immediately to NSString.
             // Wait, result.main_insight is char*. Pushing stack address is OK if callback copies.
             // But if callback deferred access... no, UpdateUICallback copies immediately.
        }
    } else {
        result.main_insight = (char*)curl_easy_strerror(res); // Safe, static string from libcurl
    }
    
    // Final Callback for Error Cases
    if (!success && callback) {
        callback(&result);
    }
    
    // Cleanup
    free(jsonString);
    cJSON_Delete(root);
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);
    free(chunk.memory);
}

void freeInsightData(InsightData *data) {
   // Since we used pointers into the cJSON structure (which is deleted after callback),
   // and the struct was on stack, we mostly don't need to do anything here if used as intended (synchronously).
   // However, if we malloc'd strings, we would free them here.
   // For now, this is a no-op as per our "zero-copy/pointer ref" strategy.
}
