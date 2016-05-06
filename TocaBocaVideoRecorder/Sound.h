//
//  Sound.h
//  TocaBocaVideoRecorder
//
//  Created by CATALINA PETERS on 5/6/16.
//  Copyright © 2016 Gramercy Tech. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface Sound : NSObject <AVAudioPlayerDelegate>

- (void)playSound:(NSString *)fileName;
- (void)stopSound;

@property (strong, nonatomic) AVAudioPlayer *player;

@end