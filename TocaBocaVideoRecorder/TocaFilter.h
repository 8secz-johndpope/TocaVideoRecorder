//
//  TocaFilter.h
//  TocaBocaVideoRecorder
//
//  Created by CATALINA PETERS on 4/28/16.
//  Copyright © 2016 Gramercy Tech. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef enum{
    FilterTypeSticker=1,
    FilterTypeFrame,
    FilterTypeFaceTracking,
    FilterTypeReset
} FilterType;


@interface TocaFilter : NSObject

@property (nonatomic, retain) NSDictionary *filterItem;
@property (nonatomic, retain) NSArray *filtersList;

- (id)initAtIndex:(int)index;

- (NSArray *)filterList;
- (int)filterType;
- (UIImage *)filterIcon;
- (UIImage *)filterIconPressed;
- (int)animationFramesAmount;
- (NSString *)animationImagePrefix;

- (float)animationHeight;
- (float)animationWidth;
// for face tracking only
- (float)animationScale;
- (float)animationXOffset;
- (float)animationYOffset;

- (float)animationX;
- (float)animationY;

@end
