#import <Cocoa/Cocoa.h>
#import "API_Client.h"

// --- Configuration ---
#define OPENROUTER_API_KEY "sk-or-placeholder"

// --- Globals ---
static NSString *lastInsight = nil;
static NSMutableArray *currentBranchStems = nil;
// Forward declaration
@class AppDelegate;
static AppDelegate *appDelegateRef = nil;

// --- Interface Declaration (Must be before C callback to recognize selectors) ---
@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (strong) NSWindow *window;
@property (strong) NSTextView *textView;
@property (strong) NSTextField *topicField;
@property (strong) NSButton *generateButton; // Renamed from newTopicButton to avoid ARC "new" rule
@property (strong) NSArray<NSButton*> *branchButtons;
- (void)updateUIWithMain:(NSString *)mainText titles:(NSArray *)titles stems:(NSArray *)stems;
@end

// --- Helper Functions ---
NSString *SafeString(const char *input) {
    if (!input) return nil;
    return [NSString stringWithUTF8String:input];
}

// Logic to bridge C callback to ObjC
void UpdateUICallback(InsightData *result) {
    // Capture data into ObjC objects immediately because 'result' is transient
    NSString *mainText = SafeString(result->main_insight);
    NSMutableArray *titles = [NSMutableArray array];
    NSMutableArray *stems = [NSMutableArray array];
    
    for (int i=0; i<3; i++) {
        NSString *t = SafeString(result->branch_titles[i]);
        NSString *s = SafeString(result->branch_stems[i]);
        [titles addObject: (t ? t : [NSNull null])];
        [stems addObject: (s ? s : [NSNull null])];
    }
    
    // Dispatch to Main Thread
    dispatch_async(dispatch_get_main_queue(), ^{
        [appDelegateRef updateUIWithMain:mainText titles:titles stems:stems];
    });
}

// --- Implementation ---
@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    appDelegateRef = self;
    currentBranchStems = [NSMutableArray arrayWithCapacity:3];
    
    // 1. Create Window (Larger Size: 800x700)
    NSRect screenRect = [[NSScreen mainScreen] visibleFrame];
    CGFloat w = 800;
    CGFloat h = 700;
    NSRect windowRect = NSMakeRect(screenRect.size.width/2 - w/2, screenRect.size.height/2 - h/2, w, h);
    self.window = [[NSWindow alloc] initWithContentRect:windowRect
                                              styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    [self.window setTitle:@"OpenRouter Insight"];
    [self.window makeKeyAndOrderFront:nil];
    
    // Layout Constants
    CGFloat margin = 20;
    CGFloat topY = h - margin;
    
    // 2. Create Topic Input Field (Top)
    // y = 700 - 20 - 30 = 650
    self.topicField = [[NSTextField alloc] initWithFrame:NSMakeRect(margin, topY - 30, w - 2*margin, 30)];
    [self.topicField setPlaceholderString:@"Enter a topic for specific insights..."];
    [self.topicField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [self.topicField setTarget:self];
    [self.topicField setAction:@selector(fetchNewTopic:)];
    [[self.window contentView] addSubview:self.topicField];
    
    // 3. Create "Generate" Button (Below Input)
    // y = 650 - 10 - 30 = 610
    self.generateButton = [[NSButton alloc] initWithFrame:NSMakeRect(w/2 - 50, topY - 70, 100, 30)];
    [self.generateButton setTitle:@"New Topic"];
    [self.generateButton setBezelStyle:NSBezelStyleRounded];
    [self.generateButton setTarget:self];
    [self.generateButton setAction:@selector(fetchNewTopic:)];
    [self.generateButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin)];
    [[self.window contentView] addSubview:self.generateButton];
    
    // 5. Create Branch Buttons Panel (Bottom)
    // Height: 150. Bottom Margin: 20. y = 20.
    CGFloat btnHeight = 150;
    CGFloat totalBtnWidth = w - 2*margin;
    CGFloat gap = 15;
    CGFloat btnWidth = (totalBtnWidth - 2*gap) / 3;
    
    NSMutableArray *buttons = [NSMutableArray array];
    for (int i = 0; i < 3; i++) {
        NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(margin + i*(btnWidth+gap), margin, btnWidth, btnHeight)];
        [btn setTitle:[NSString stringWithFormat:@"Idea %d", i+1]];
        [btn setBezelStyle:NSBezelStyleRegularSquare]; // Supports larger areas better
        [[btn cell] setWraps:YES]; // Enable text wrapping
        [[btn cell] setLineBreakMode:NSLineBreakByWordWrapping];
        [btn setFont:[NSFont systemFontOfSize:13]]; // Slightly legible font
        
        [btn setTarget:self];
        [btn setAction:@selector(branchButtonAction:)];
        [btn setTag:i];
        [btn setEnabled:NO];
        [btn setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin | NSViewMinXMargin | NSViewMaxXMargin)];
        
        // Distribute resizing
        // Since we can't easily set proportional autoresizing mask without constraints, 
        // we'll stick to a simple mask that keeps them anchored to bottom.
        // For distinct resizing logic, we'd need NSLayoutConstraint, but strictly frame-based:
        // Let's create them with Fixed margins for simplicity in this frame-based approach 
        // or just let them float.
        // Actually, simple frame-based resizing for 3 columns is tricky. 
        // For now, let's keep them anchored left/right/center approximately or just anchored bottom-left.
        // We will pin them to bottom.
        
        [[self.window contentView] addSubview:btn];
        [buttons addObject:btn];
    }
    self.branchButtons = buttons;
    
    // 4. Create Scroll View & Text View (Middle)
    // Y starts above buttons + 20 gap = 20 + 150 + 20 = 190.
    // Height ends below Generate Button - 20 gap = 610 - 20 = 590.
    // Height = 590 - 190 = 400.
    CGFloat scrollY = margin + btnHeight + margin;
    CGFloat scrollH = (topY - 70) - margin - scrollY; 
    
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(margin, scrollY, w - 2*margin, scrollH)];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setBorderType:NSBezelBorder];
    [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    
    self.textView = [[NSTextView alloc] initWithFrame:scrollView.contentView.bounds];
    [self.textView setEditable:NO];
    [self.textView setFont:[NSFont systemFontOfSize:16]]; // Increased font size for readability
    [self.textView setString:@"Enter a topic and click 'New Topic' to start."];
    
    [scrollView setDocumentView:self.textView];
    [[self.window contentView] addSubview:scrollView];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // No specific cleanup
}

- (void)fetchNewTopic:(id)sender {
    [self startRequestWithBranchIndex:-1];
}

- (void)branchButtonAction:(NSButton *)sender {
    [self startRequestWithBranchIndex:sender.tag];
}

- (void)startRequestWithBranchIndex:(NSInteger)branchIndex {
    // Disable all buttons
    [self.generateButton setEnabled:NO];
    for (NSButton *btn in self.branchButtons) {
        [btn setEnabled:NO];
    }
    
    [self.textView setString:@"Thinking... \n(Calling OpenRouter)"];
    
    // Prepare Data
    NSString *topicObj = [self.topicField stringValue];
    NSString *topic = topicObj ? [topicObj copy] : @"";
    
    NSString *prevString = nil;
    if (branchIndex == -1 && lastInsight) {
        prevString = [lastInsight copy];
    }
    
    NSString *stemString = nil;
    if (branchIndex >= 0 && branchIndex < currentBranchStems.count) {
        id s = currentBranchStems[branchIndex];
        if ([s isKindOfClass:[NSString class]]) {
            stemString = [s copy];
        }
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        const char *t = [topic length] > 0 ? [topic UTF8String] : NULL;
        const char *p = [prevString length] > 0 ? [prevString UTF8String] : NULL;
        const char *s = [stemString length] > 0 ? [stemString UTF8String] : NULL;
        
        fetchInsight(t, p, s, &UpdateUICallback);
    });
}

- (void)updateUIWithMain:(NSString *)mainText titles:(NSArray *)titles stems:(NSArray *)stems {
    if (mainText && mainText.length > 0) {
        [self.textView setString:mainText];
        lastInsight = [mainText copy];
        
        [currentBranchStems removeAllObjects];
        
        for (int i=0; i<3; i++) {
            if (i < titles.count) {
                NSString *t = titles[i];
                NSString *s = stems[i];
                NSButton *btn = self.branchButtons[i];
                
                if (t && ![t isEqual:[NSNull null]] && s && ![s isEqual:[NSNull null]]) {
                    [btn setTitle:t];
                    [currentBranchStems addObject:s];
                    [btn setEnabled:YES];
                } else {
                    [btn setTitle:@"-"];
                    [currentBranchStems addObject:[NSNull null]];
                    [btn setEnabled:NO];
                }
            } else {
                NSButton *btn = self.branchButtons[i];
                [btn setTitle:@"-"];
                [currentBranchStems addObject:[NSNull null]];
                [btn setEnabled:NO];
            }
        }
    } else {
        [self.textView setString:@"Error: Failed to fetch (or parse) insight."];
    }
    
    [self.generateButton setEnabled:YES];
}

@end

// --- Entry Point ---
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        [app setDelegate:delegate];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        [app run];
    }
    return 0;
}
