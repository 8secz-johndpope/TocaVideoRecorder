//
//  TocaFilter.m
//  TocaBocaVideoRecorder
//
//  Created by CATALINA PETERS on 4/28/16.
//  Copyright © 2016 Gramercy Tech. All rights reserved.
//

#import "TocaFilter.h"

@implementation TocaFilter

- (id)initAtIndex:(int)index {
    self = [super init];
    if (self) {
        NSString *plistPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"TocaFilters.plist"];
        self.filtersList = [[NSArray alloc] initWithContentsOfFile:plistPath];
        if(index > -1) {
            self.filterItem = [self.filterList objectAtIndex:index];
        }
    }
    return self;
}

- (NSArray *)filterList {
    return self.filtersList;
}

- (int)filterType {
    if( [self.filterItem[@"type"] isEqualToString:@"sticker"]) {
        return FilterTypeSticker;
    } else if([self.filterItem[@"type"] isEqualToString:@"animated-scene"]) {
        return FilterTypeFrame;
    } else if([self.filterItem[@"type"] isEqualToString:@"face-tracking"]) {
        return FilterTypeFaceTracking;
    } else {
        return FilterTypeReset;
    }
}

- (UIImage *)filterIcon {
    return [UIImage imageNamed:self.filterItem[@"icon-image"]];
}

- (UIImage *)filterIconPressed {
    return [UIImage imageNamed:self.filterItem[@"icon-image-pressed"]];
}

- (int)animationFramesAmount {
    return [self.filterItem[@"animation-frames-amount"] intValue];
}

- (float)animationHeight {
    if(!self.filterItem[@"animation-height"]) {
        return 0;
    } else {
        return [self.filterItem[@"animation-height"] floatValue];
    }
}

- (float)animationWidth {
    if(!self.filterItem[@"animation-width"]) {
        return 0;
    } else {
        return [self.filterItem[@"animation-width"] floatValue];
    }
}

- (NSString *)animationImagePrefix {
    return self.filterItem[@"animation-image-prefix"];
}

// for face tracking need percentage away from origin
- (float)animationScale {
    if(!self.filterItem[@"animation-scale"]) {
        return 1.0;
    } else {
        return [self.filterItem[@"animation-scale"] floatValue];
    }
}

- (float)animationXOffset {
    if(!self.filterItem[@"animation-x-offset"]) {
        return 0.0;
    } else {
        return [self.filterItem[@"animation-x-offset"] floatValue];
    }
}

- (float)animationYOffset {
    if(!self.filterItem[@"animation-y-offset"]) {
        return 0.0;
    } else {
        return [self.filterItem[@"animation-y-offset"] floatValue];
    }
}

// for frames need specific pixels, have exact pixels for 1024 X 768 and I convert
- (float)animationX {
    if(!self.filterItem[@"animation-x"]) {
        return 0.0;
    } else {
        return [self.filterItem[@"animation-x"] floatValue];
    }
}

- (float)animationY {
    if(!self.filterItem[@"animation-y"]) {
        return 0.0;
    } else {
        return [self.filterItem[@"animation-y"] floatValue];
    }
}

- (NSString *)soundFilePath {
    if(!self.filterItem[@"sound-file"] || [self.filterItem[@"sound-file"] isEqualToString:@""]) {
        return @"";
    } else {
        return [[NSBundle mainBundle] pathForResource:self.filterItem[@"sound-file"] ofType:@"mp3"];
    }
}

@end
