//
//  Sound.m
//  TocaBocaVideoRecorder
//
//  Created by CATALINA PETERS on 5/6/16.
//  Copyright © 2016 Gramercy Tech. All rights reserved.
//

#import "Sound.h"

@implementation Sound

- (void)playSound:(NSString *)filePath {
    
    NSURL *scanSoundURL = [NSURL fileURLWithPath:filePath];
    NSError *error;
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL: scanSoundURL error:&error];
    if(error){
        NSLog(@"Error playing sound: %@", error);
    }
    
    scanSoundURL = nil;
    self.player.delegate = self;
    self.player.volume = 1.0;
    self.player.numberOfLoops = -1;
    [self.player play];
}

- (void)stopSound {
    if(self.player && [self.player isPlaying]) {
        [self.player stop];
        self.player = nil;
    }
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    if(flag) {
        self.player = nil;
    }
}

- (void)dealloc {
    self.player = nil;
}

@end

