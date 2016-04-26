//
//  ViewController.h
//  TocaBocaVideoRecorder
//
//  Created by Ben Honig on 4/22/16.
//  Copyright © 2016 Gramercy Tech. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GPUImage.h"
@import AVFoundation;
@import AVKit;

@interface ViewController : UIViewController <GPUImageVideoCameraDelegate>
{

    GPUImageVideoCamera *videoCamera;
    BOOL faceThinking;
    GPUImageUIElement *uiElementInput;
}

@property (weak, nonatomic) IBOutlet UIButton *recordButton;
@property (weak, nonatomic) IBOutlet UICollectionView *filterCollectionView;
@property (weak, nonatomic) IBOutlet UICollectionView *savedVideosCollectionView;
@property (weak, nonatomic) IBOutlet UIView *videoCaptureView;
@property (weak, nonatomic) IBOutlet GPUImageView *filteredVideoView;
@property (strong, nonatomic) GPUImageOutput<GPUImageInput> *filter;
@property (strong, nonatomic) GPUImageMovieWriter *movieWriter;
@property (strong, nonatomic) CIDetector*faceDetector;
@property (strong, nonatomic) UIImageView *faceView;
@property BOOL isRecording;
@property BOOL isFaceSwitched;
@property BOOL isUserInterfaceElementVideo;


- (IBAction)recordStartStop:(id)sender;
- (void)willOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)GPUVCWillOutputFeatures:(NSArray*)featureArray forClap:(CGRect)clap
                 andOrientation:(UIDeviceOrientation)curDeviceOrientation;

@end

