//
//  ViewController.h
//  TocaBocaVideoRecorder
//
//  Created by Ben Honig on 4/22/16.
//  Copyright © 2016 Gramercy Tech. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <AVKit/AVKit.h>
#import "GPUImage.h"
#import "TocaFilter.h"
#import "Sound.h"
@import AVFoundation;
@import AVKit;

typedef enum{
    VideoElementTypeSticker=1,
    VideoElementTypeFrame,
    VideoElementTypeFaceTracking
} VideoElementType;


@interface ViewController : UIViewController <GPUImageVideoCameraDelegate, UITextFieldDelegate>
{
    NSString *fileSavedPath;
    GPUImageVideoCamera *videoCamera;
    BOOL faceThinking;
    GPUImageUIElement *uiElementInput;
    GPUImagePicture *gpuImagePicture;
    CGRect faceCGRect;
    int selectedIndex;
    TocaFilter *selectedFilter;
    UIInterfaceOrientation currentInterfaceOrientation;
    NSTimer *videoRecordTimeOutTimer;
    float countForProgress;
    CGRect originalVideoContainerFrame;
}

@property (weak, nonatomic) IBOutlet UIButton *recordButton;
@property (weak, nonatomic) IBOutlet UIView *videoItemsContainer;
@property (weak, nonatomic) IBOutlet UIButton *switchCameraButton;
@property (weak, nonatomic) IBOutlet UICollectionView *filterCollectionView;
@property (weak, nonatomic) IBOutlet UICollectionView *savedVideosCollectionView;
@property (weak, nonatomic) IBOutlet UIView *videoCaptureView;
@property (weak, nonatomic) IBOutlet GPUImageView *filteredVideoView;
@property (weak, nonatomic) IBOutlet UIProgressView *videoProgressView;
@property (strong, nonatomic) IBOutlet UIImageView *collectionTabImage;
@property (strong, nonatomic) IBOutlet UIImageView *duplicateVideoImage;


@property (strong, nonatomic) UITextField *videoNameLabel;
@property (strong, nonatomic) UILabel *videoAuthorLabel;

@property (strong, nonatomic) UIButton *deleteVideoButton;
@property (strong, nonatomic) UIButton *saveVideoButton;
@property (strong, nonatomic) UIButton *replayVideoButton;
@property (strong, nonatomic) AVPlayer *previewMoviePlayer;

@property (strong, nonatomic) GPUImageOutput<GPUImageInput> *filter;
@property (strong, nonatomic) GPUImageAlphaBlendFilter *blendFilter;
@property (strong, nonatomic) GPUImageMovieWriter *movieWriter;
@property (strong, nonatomic) CIDetector*faceDetector;
@property (strong, nonatomic) UIView *faceView;
@property (strong, nonatomic) UIView *previewView;
@property (strong, nonatomic) UIView *contentView;
@property (strong, nonatomic) UIView *previewMovieView;
@property (strong, nonatomic) UIImageView *animatedImageView;
@property BOOL isRecording;
@property BOOL isFaceSwitched;
@property BOOL isUserInterfaceElementVideo;



- (IBAction)recordStartStop:(id)sender;
- (void)willOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)GPUVCWillOutputFeatures:(NSArray*)featureArray forClap:(CGRect)clap
                 andOrientation:(UIDeviceOrientation)curDeviceOrientation;

@end

