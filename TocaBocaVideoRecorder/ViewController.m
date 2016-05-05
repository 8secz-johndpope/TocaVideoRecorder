//
//  ViewController.m
//  TocaBocaVideoRecorder
//
//  Created by Ben Honig on 4/22/16.
//  Copyright © 2016 Gramercy Tech. All rights reserved.
//

#import "ViewController.h"
#import "CustomCollectionCell.h"

//static CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};
static CGFloat videoDurationMaximum = 29.0;
static CGFloat buttonSize = 108.0;

@interface ViewController ()
{
    CGPoint initialStickerDragPoint;
    CGPoint lastStickerDragPoint;
}

@property (nonatomic, strong) NSMutableArray* savedVideos;
@property (nonatomic, strong) NSArray* filters;
@property (nonatomic, strong) UIActivityIndicatorView *activityView;
@property (nonatomic, strong) NSURL *videoPlayerURL;

@end

@implementation ViewController 


static NSString * const reuseIdentifier = @"CustomCollectionCell";

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    countForProgress = 0.0;
    
    originalVideoContainerFrame = _videoItemsContainer.frame;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateFaceTrackingFrame:)
                                                 name:@"updateFaceTrackingFrame"
                                               object:nil];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceOrientationDidChange:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
    _isRecording = false;
    selectedIndex = 0;
    
    faceCGRect = CGRectMake(0, 0, 0, 0);
    
    self.filterCollectionView.allowsSelection = YES;
    self.filterCollectionView.tag = 1;
    self.savedVideosCollectionView.allowsSelection = YES;
    self.savedVideosCollectionView.tag = 2;
   
    _savedVideos = [self savedVideos];
    
    _filters = [[[TocaFilter alloc] initAtIndex:-1] filterList];
    
    // They want video output to be 16:9
    videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset1280x720 cameraPosition:AVCaptureDevicePositionFront];

    currentInterfaceOrientation = [UIApplication sharedApplication].statusBarOrientation;
    videoCamera.outputImageOrientation = currentInterfaceOrientation;

    [videoCamera setHorizontallyMirrorFrontFacingCamera:YES];
    [videoCamera setHorizontallyMirrorRearFacingCamera:NO];
    
//    _filter = [[GPUImageFilter alloc] init];
    _filter = [[GPUImageSaturationFilter alloc] init];
    [videoCamera addTarget:_filter];
    [_filter addTarget:_filteredVideoView];
    
    [videoCamera startCameraCapture];
    
    //set up face detector
    if ([GPUImageContext supportsFastTextureUpload])
    {
        NSDictionary *detectorOptions = [[NSDictionary alloc] initWithObjectsAndKeys:CIDetectorAccuracyLow, CIDetectorAccuracy, nil];
        self.faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:detectorOptions];
        faceThinking = NO;
    }
    
    _isFaceSwitched = NO;
    _isUserInterfaceElementVideo = NO;
    
    _filteredVideoView.fillMode = kGPUImageFillModePreserveAspectRatioAndFill;
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
   /// originalVideoContainerFrame = _videoItemsContainer.frame;
    
}

- (NSMutableArray *)savedVideos{
    NSString *pathToMovie = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/"];
    
    NSArray* dirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:pathToMovie
                                                                        error:NULL];
    NSMutableArray *m4vFiles = [[NSMutableArray alloc] init];
    [dirs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *filename = (NSString *)obj;
        NSString *extension = [[filename pathExtension] lowercaseString];
        if ([extension isEqualToString:@"m4v"]) {
            //filter for just toca
            if ([filename containsString:@"Toca"]){
                [m4vFiles addObject:[pathToMovie stringByAppendingPathComponent:filename]];
            }
        }
    }];
    
    return m4vFiles;
}

-(NSString *)videoFileName: (int) len {
    //random string
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *randomString = [NSMutableString stringWithCapacity: len];
    
    for (int i=0; i<len; i++) {
        [randomString appendFormat: @"%C", [letters characterAtIndex: arc4random_uniform([letters length])]];
    }
    
    return randomString;
}

- (IBAction)switchCamera:(id)sender {
    if(videoCamera) {
        [videoCamera rotateCamera];
    }
}

- (IBAction)recordStartStop:(id)sender{
    
    //record the video
    if (_isRecording) {
        
        _recordButton.userInteractionEnabled = NO;
        
        //stop recording
        _isRecording = false;
        
        [_recordButton setImage:[UIImage imageNamed:@"Record.png"] forState:UIControlStateNormal];
        [_recordButton setImage:[UIImage imageNamed:@"RecordPress.png"] forState:UIControlStateHighlighted];
        [_recordButton setImage:[UIImage imageNamed:@"RecordPress.png"] forState:UIControlStateHighlighted];
        
        _activityView = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(CGRectGetMidX(self.view.frame), CGRectGetMidY(self.view.frame), 30, 30)];
        _activityView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
        [self.view addSubview:_activityView];
        [_activityView startAnimating];
        
        videoCamera.audioEncodingTarget = nil;
        
        __weak typeof(self) weakSelf = self;
        [_movieWriter finishRecordingWithCompletionHandler:^{
            [weakSelf.filter removeTarget:weakSelf.movieWriter];
            [weakSelf.movieWriter finishRecording];
            
            //refresh collection view
            _savedVideos = nil;
            _savedVideos = [self savedVideos];
            
           
            dispatch_async(dispatch_get_main_queue(), ^{
                
                
                [_activityView stopAnimating];
                [_activityView removeFromSuperview];
                
                [weakSelf.savedVideosCollectionView reloadData];
                [self resetVideoCamera];
                
                [self showSavedVideoView];
                
                if(videoRecordTimeOutTimer) {
                    [videoRecordTimeOutTimer invalidate];
                    videoRecordTimeOutTimer = nil;
                }
                countForProgress = 0.0;
                _videoProgressView.progress = 0.0;
                
                NSLog(@"completed");
            });
            
        }];
    }else{
         _recordButton.userInteractionEnabled = NO;
        
        _isRecording = true;

        [_recordButton setImage:[UIImage imageNamed:@"Stop.png"] forState:UIControlStateNormal];
        [_recordButton setImage:[UIImage imageNamed:@"StopPress.png"] forState:UIControlStateHighlighted];
        [_recordButton setImage:[UIImage imageNamed:@"StopPress.png"] forState:UIControlStateHighlighted];

        videoCamera.outputImageOrientation = [UIApplication sharedApplication].statusBarOrientation;

        //stored in Documents which can  be accessed by iTunes (this can change)
        NSString *pathToMovie = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Documents/Toca-%@.m4v", [self videoFileName:6]]];
        fileSavedPath = pathToMovie;
        unlink([pathToMovie UTF8String]); // If a file already exists, AVAssetWriter won't let you record new frames, so delete the old movie
        NSURL *movieURL = [NSURL fileURLWithPath:pathToMovie];
        _movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:CGSizeMake(1280.0, 720.0)];
        
        _movieWriter.encodingLiveVideo = YES;
        [_blendFilter addTarget:_movieWriter];
        
        double delayToStartRecording = 1.2;
        dispatch_time_t startTime = dispatch_time(DISPATCH_TIME_NOW, delayToStartRecording * NSEC_PER_SEC);
        dispatch_after(startTime, dispatch_get_main_queue(), ^(void){
            NSLog(@"Start recording");
            
            _recordButton.userInteractionEnabled = YES;
            if(videoRecordTimeOutTimer) {
                [videoRecordTimeOutTimer invalidate];
                videoRecordTimeOutTimer = nil;
            }
            countForProgress = 0.0;
            
            videoRecordTimeOutTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(videoTimerFired) userInfo:nil repeats:YES];
            
            videoCamera.audioEncodingTarget = _movieWriter;
            [_movieWriter startRecording];
        });
    }
}

- (void)videoTimerFired {
    if(_isRecording) {
        if(countForProgress >= videoDurationMaximum) {
            [self recordStartStop:nil];
        } else {
            countForProgress+=0.10;
        }
        [_videoProgressView setProgress:(countForProgress / videoDurationMaximum) animated:YES];
    }
}


- (void)startVideoFilter {
    
    _blendFilter = [[GPUImageAlphaBlendFilter alloc] init];
    _blendFilter.mix = 1.0;
    
    [videoCamera addTarget:_filter];
    
    UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, _filteredVideoView.frame.size.width, _filteredVideoView.frame.size.height)];
    contentView.backgroundColor = [UIColor clearColor];
    
  
    uiElementInput = nil;
    
    switch ([selectedFilter filterType]) {
        case FilterTypeReset:
            NSLog(@"reset select");
            
            float height = 0;
            float width = 0;
            float framex = 0;
            float framey = 0;
            
            videoCamera.delegate = nil;
            _isUserInterfaceElementVideo = NO;
            
           // uiElementInput = [[GPUImageUIElement alloc] initWithView:contentView];
            break;
            
        case FilterTypeSticker:
            NSLog(@"sticker select");
            videoCamera.delegate = nil;
            _isUserInterfaceElementVideo = NO;
            
            height = [selectedFilter animationHeight];
            width = [selectedFilter animationWidth];
            
            framex = ((contentView.frame.size.width - width) / 2);
            framey = ((contentView.frame.size.height - height) / 2);
            
            _previewView = [[UIView alloc] initWithFrame:CGRectMake(_filteredVideoView.frame.origin.x, _filteredVideoView.frame.origin.y, _filteredVideoView.frame.size.width, _filteredVideoView.frame.size.height)];
            
            _previewView.backgroundColor = [UIColor clearColor];
            _animatedImageView = [[UIImageView alloc] initWithFrame:CGRectMake(framex, framey, width, height)];
            
            _animatedImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"%@00000.png", [selectedFilter animationImagePrefix]]];
            [contentView addSubview:_animatedImageView];
            
            break;
            
        case FilterTypeFrame:
            NSLog(@"frame select");
            videoCamera.delegate = nil;
            _isUserInterfaceElementVideo = NO;
            
            float ratioX = _filteredVideoView.frame.size.width / 1024.0;
            float ratioY = _filteredVideoView.frame.size.height / 768.0;
            
            float newX = [selectedFilter animationX] * ratioX;
            float newY = [selectedFilter animationY] * ratioY;
            
            width = [selectedFilter animationWidth];
            height = [selectedFilter animationHeight];
            
            if(width == 960) {
                
                width = _filteredVideoView.frame.size.width;
                height = [selectedFilter animationHeight] * (_filteredVideoView.frame.size.width / [selectedFilter animationWidth]);
            } else if (height == 540) {
                height = _filteredVideoView.frame.size.height;
                width = [selectedFilter animationWidth] * (_filteredVideoView.frame.size.height / [selectedFilter animationHeight]);
            }
            
            _animatedImageView = [[UIImageView alloc] initWithFrame:CGRectMake(newX, newY, width, height)];
            
            _animatedImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"%@00000.png", [selectedFilter animationImagePrefix]]];
            
            [contentView addSubview:_animatedImageView];
            
            break;
            
        case FilterTypeFaceTracking:
            NSLog(@"face tracking select");
            _isUserInterfaceElementVideo = YES;
            videoCamera.delegate = self;
            
            height = [selectedFilter animationHeight];
            width = [selectedFilter animationWidth];
            
            framex = ((contentView.frame.size.width - width) / 2);
            framey = ((contentView.frame.size.height - height) / 2);
            
            _animatedImageView = [[UIImageView alloc] initWithFrame:CGRectMake(framex, framey, width, height)];
            _animatedImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"%@00000.png", [selectedFilter animationImagePrefix]]];
            
            [contentView addSubview:_animatedImageView];
            
            break;
            
        default:
            NSLog(@"default select");
            _isUserInterfaceElementVideo = NO;
            videoCamera.delegate = nil;
            
            break;
    }
    
    if([selectedFilter filterType] == FilterTypeSticker) {
        
        // making a fake image to attach uigesture to for dragging while recording
        UIImageView *testImage = [[UIImageView alloc] initWithFrame:_animatedImageView.frame];
        testImage.backgroundColor = [UIColor clearColor];
        
        UIPanGestureRecognizer *dragRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragSticker:)];
        testImage.userInteractionEnabled = YES;
        testImage.gestureRecognizers = @[dragRecognizer];
        
        [_previewView addSubview:testImage];
        testImage = nil;
        [_videoItemsContainer addSubview:_previewView];
        [_videoItemsContainer bringSubviewToFront:_switchCameraButton];
    }

    
    [videoCamera setDelegate:self];
    
    _animatedImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"%@00000.png", [selectedFilter animationImagePrefix]]];
    
    [contentView addSubview:_animatedImageView];
    
    uiElementInput = [[GPUImageUIElement alloc] initWithView:contentView];
    contentView = nil;

    [_filter addTarget:_blendFilter];
    [uiElementInput addTarget:_blendFilter];
    
    [_blendFilter addTarget:_filteredVideoView];
    
    _animatedImage = nil;
    _animatedImage = [UIImage imageNamed:[NSString stringWithFormat:@"%@00000.png", [selectedFilter animationImagePrefix]]];
    
    GPUImageUIElement *weakUIElementInput = uiElementInput;
    __block int indexItem = 0;
    UIImageView *weakImageView = _animatedImageView;
   // __block UIImage *weakImage = _animatedImage;
    __block TocaFilter *weakTocaFilter = selectedFilter;
    [_filter setFrameProcessingCompletionBlock:^(GPUImageOutput * filter, CMTime frameTime){
        
        if([weakTocaFilter animationFramesAmount] > 0) {
            
            if (indexItem == [weakTocaFilter animationFramesAmount]) {
                indexItem = 0;
            } else {
                indexItem++;
            }
            
            //for malloc error
//            dispatch_async(dispatch_get_global_queue
//                           (DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
                UIImage *weakImage = [UIImage imageNamed:[NSString stringWithFormat:@"%@%05d.png", [weakTocaFilter animationImagePrefix], indexItem]];
                weakImageView.image = weakImage;
                weakImage = nil;
               //image = nil;
               
//            });
        }
        [weakUIElementInput update];
    }];
   
    [videoCamera stopCameraCapture];
    [videoCamera startCameraCapture];
}

- (void)resetVideoCamera {
    // index 0 is reset
    if(_previewView) {
        [_previewView removeFromSuperview];
        _previewView = nil;
    }
    
    NSIndexPath *path = [NSIndexPath indexPathForItem:0 inSection:1];
    [self collectionView:self.filterCollectionView didSelectItemAtIndexPath:path];
}

#pragma mark - Saving Video + Animations

- (void)showSavedVideoView {
    NSLog(@"show saved cameraview");
    [videoCamera stopCameraCapture];
    
    _recordButton.userInteractionEnabled = NO;
    _filterCollectionView.userInteractionEnabled = NO;
    
    _previewMovieView = [[UIView alloc] initWithFrame:_filteredVideoView.frame];
    
    AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:fileSavedPath]];
    AVPlayerItem *playerItem = [[AVPlayerItem alloc] initWithAsset:asset];
    _previewMoviePlayer = [AVPlayer playerWithPlayerItem:playerItem];
    
    AVPlayerLayer *previewMovieLayer =[AVPlayerLayer playerLayerWithPlayer:_previewMoviePlayer];
    previewMovieLayer.frame = CGRectMake(0, 0, _filteredVideoView.frame.size.width, _filteredVideoView.frame.size.height);
    
    previewMovieLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    previewMovieLayer.needsDisplayOnBoundsChange = YES;
   
    [_previewMovieView.layer addSublayer:previewMovieLayer];
    [_videoItemsContainer addSubview:_previewMovieView];
    
    [_previewMoviePlayer play];
    
    _deleteVideoButton = [[UIButton alloc] initWithFrame:CGRectMake((_filteredVideoView.frame.origin.x - (buttonSize/2)), (_filteredVideoView.frame.origin.y - (buttonSize/2)), buttonSize, buttonSize)];
    [_deleteVideoButton setImage:[UIImage imageNamed:@"Trash.png"] forState:UIControlStateNormal];
    [_deleteVideoButton setImage:[UIImage imageNamed:@"TrashPress.png"] forState:UIControlStateHighlighted];
    [_deleteVideoButton setImage:[UIImage imageNamed:@"TrashPress.png"] forState:UIControlStateHighlighted];
    [_deleteVideoButton addTarget:nil action:@selector(tapDeleteIcon:) forControlEvents:UIControlEventTouchUpInside];
    [_videoItemsContainer addSubview:_deleteVideoButton];
    
    _saveVideoButton = [[UIButton alloc] initWithFrame:CGRectMake(((_filteredVideoView.frame.origin.x+_filteredVideoView.frame.size.width) - (buttonSize/2)), (_filteredVideoView.frame.origin.y - (buttonSize/2)), buttonSize, buttonSize)];
    [_saveVideoButton setImage:[UIImage imageNamed:@"SaveCollect.png"] forState:UIControlStateNormal];
    [_saveVideoButton setImage:[UIImage imageNamed:@"SaveCollectPress.png"] forState:UIControlStateHighlighted];
    [_saveVideoButton setImage:[UIImage imageNamed:@"SaveCollectPress.png"] forState:UIControlStateHighlighted];
    [_saveVideoButton addTarget:nil action:@selector(tapSaveIcon:) forControlEvents:UIControlEventTouchUpInside];
    [_videoItemsContainer addSubview:_saveVideoButton];
    
    asset = nil;
    playerItem = nil;
    previewMovieLayer = nil;
}

- (void)removeSavedVideoView {
    [_deleteVideoButton removeFromSuperview];
    _deleteVideoButton = nil;
    
    [_saveVideoButton removeFromSuperview];
    _saveVideoButton = nil;
    
    [_previewMovieView removeFromSuperview];
    _previewMovieView = nil;
    
    if(_videoNameLabel){
        if([_videoNameLabel isFirstResponder]){
            [_videoNameLabel resignFirstResponder];
        }
        [_videoNameLabel removeFromSuperview];
        _videoNameLabel = nil;
    }
    
    if(_previewMoviePlayer){
        [_previewMoviePlayer pause];
        _previewMoviePlayer = nil;
    }
    
    NSError *error;
    if([[NSFileManager defaultManager] fileExistsAtPath:fileSavedPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:fileSavedPath error:&error];
        if(!error){
            fileSavedPath = nil;
            NSLog(@"delete the file");
        }
    }
    _recordButton.userInteractionEnabled = YES;
    _filterCollectionView.userInteractionEnabled = YES;
    
    [videoCamera startCameraCapture];
}

- (void)hideCreationToolButtonsAndShiftVideoPlayer {
    
    _filteredVideoView.hidden = YES;
    float translationAmount = -(self.view.frame.size.width / 5);
    float tabRatio = (1012.0 / 1024.0);
    float tabWidth =  self.view.frame.size.width * tabRatio;
    
//    float collectionOriginX = (0.914 * tabWidth);
    float dragToOpenConstant = self.view.frame.size.width - (self.view.frame.size.width / 3);
    
    _collectionTabImage = [[UIImageView alloc] initWithFrame:CGRectMake(self.view.frame.size.width, 0, tabWidth, self.view.frame.size.height)];
    _collectionTabImage.image = [UIImage imageNamed:@"Collection-Tab-BG.png"];
    [self.view addSubview:_collectionTabImage];

    [self.view bringSubviewToFront:_videoItemsContainer];
    
    [UIView animateWithDuration:0.33f delay:0.0f options:UIViewAnimationOptionTransitionNone animations:^{
        _recordButton.alpha = 0.0;
        _filterCollectionView.alpha = 0.0;
        
        CGAffineTransform videoPlayerShrink = CGAffineTransformScale(_videoItemsContainer.transform, 0.70, 0.70);
        CGAffineTransform videoPlayerShift = CGAffineTransformMakeTranslation(translationAmount, 0);
        _videoItemsContainer.transform = CGAffineTransformConcat(videoPlayerShrink, videoPlayerShift);
    
        _collectionTabImage.frame = CGRectMake(dragToOpenConstant, 0, tabWidth, self.view.frame.size.height);
    
    } completion:^(BOOL finished) {
        _recordButton.hidden = YES;
        _filterCollectionView.hidden = YES;
        [self moveVideoToCollectionTab];
    }];
}

- (void)moveVideoToCollectionTab {
    [UIView animateWithDuration:0.33f delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^{
        
        CGAffineTransform videoPlayerShrink = CGAffineTransformScale(_videoItemsContainer.transform, 0.4, 0.4);
        
        _videoItemsContainer.transform = videoPlayerShrink;
        _videoItemsContainer.frame = CGRectMake(((self.view.frame.size.width - _videoItemsContainer.frame.size.width) - 12), _collectionTabImage.frame.origin.y + 55, _videoItemsContainer.frame.size.width, _videoItemsContainer.frame.size.height);
        
    } completion:^(BOOL finished) {
        
        [self closeCollectionTab];
        
    }];
}

- (void)closeCollectionTab {
    
    _recordButton.hidden = NO;
    _filterCollectionView.hidden = NO;
    
    [UIView animateWithDuration:1.0f delay:0.3f options:UIViewAnimationOptionCurveEaseOut animations:^{
        
        CGRect newCollection = _collectionTabImage.frame;
        newCollection.origin.x += 600;
        _collectionTabImage.frame = newCollection;
        
        CGRect newContainer = _videoItemsContainer.frame;
        newContainer.origin.x += 600;
        _videoItemsContainer.frame = newContainer;
        
       
        _recordButton.alpha = 1.0;
        _filterCollectionView.alpha = 1.0;
        
    } completion:^(BOOL finished) {
        _videoItemsContainer.alpha = 0.0;
        _videoItemsContainer.transform = CGAffineTransformIdentity;
        
        [_deleteVideoButton removeFromSuperview];
        _deleteVideoButton = nil;
        
        [_saveVideoButton removeFromSuperview];
        _saveVideoButton = nil;
        
        [_previewMovieView removeFromSuperview];
        _previewMovieView = nil;
        
        if(_videoNameLabel){
            if([_videoNameLabel isFirstResponder]){
                [_videoNameLabel resignFirstResponder];
            }
            [_videoNameLabel removeFromSuperview];
            _videoNameLabel = nil;
        }
        
        if(_previewMoviePlayer){
            [_previewMoviePlayer pause];
            _previewMoviePlayer = nil;
        }
        
        [self showCreationToolButtons];
        
        [videoCamera startCameraCapture];
    }];
}
     

- (void)showCreationToolButtons {
    _videoItemsContainer.frame = originalVideoContainerFrame;
    _filteredVideoView.hidden = NO;
    
    [UIView animateWithDuration:0.4 animations:^{
        _videoItemsContainer.alpha = 1.0;
    } completion:^(BOOL finished) {
        _recordButton.userInteractionEnabled = YES;
        _filterCollectionView.userInteractionEnabled = YES;
    }];
}

#pragma mark -

- (IBAction)tapDeleteIcon:(id)sender {
    [self removeSavedVideoView];
}

- (IBAction)tapSaveIcon:(id)sender {
    
    if(_videoNameLabel.text.length > 0) {
        [self saveVideoToCameraRoll];
    } else {
        _videoNameLabel = [[UITextField alloc] initWithFrame:CGRectMake(_filteredVideoView.frame.origin.x+60, _filteredVideoView.frame.origin.y+60, _filteredVideoView.frame.size.width - 120, 45)];
        _videoNameLabel.borderStyle = UITextBorderStyleLine;
        _videoNameLabel.backgroundColor = [UIColor whiteColor];
        _videoNameLabel.keyboardType = UIKeyboardTypeAlphabet;
        _videoNameLabel.autocorrectionType = UITextAutocapitalizationTypeWords;
        _videoNameLabel.returnKeyType = UIReturnKeyDone;
        _videoNameLabel.font = [UIFont systemFontOfSize:18];
        _videoNameLabel.delegate = self;
        
        [_videoItemsContainer addSubview:_videoNameLabel];
        [_videoNameLabel becomeFirstResponder];
    }
}

- (void)saveVideoToCameraRoll {
    
    _videoNameLabel.userInteractionEnabled = NO;
    [self.view bringSubviewToFront:_activityView];
    [_activityView startAnimating];
    
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^
     {
         NSURL *videoURL = [NSURL URLWithString:fileSavedPath];
         
         PHAssetCreationRequest *createRequest = [PHAssetCreationRequest creationRequestForAssetFromVideoAtFileURL:videoURL];
         createRequest.creationDate = [NSDate date];
     } completionHandler:^(BOOL success, NSError *error)
     {
         NSString *title;
         NSString *message;
         if (success)
         {
             NSLog(@"photo library successfully saved");
             title = @"Video Saved";
             message = @"Check your Camera Roll for your saved video";
             
             
             fileSavedPath = nil;
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 [self animateSavedVideoToCollection];
                 
                 [_videoNameLabel removeFromSuperview];
                 _videoNameLabel = nil;
                 
                 [_deleteVideoButton removeFromSuperview];
                 _deleteVideoButton = nil;
                 
                 [_saveVideoButton removeFromSuperview];
                 _saveVideoButton = nil;
                 
             });
         }
         else
         {
             title = @"Error";
             message = @"There was an error saving your video";

             NSLog(@"photo library error saving to photos: %@", error);
         }


         UIAlertController *alertController = [UIAlertController
                                               alertControllerWithTitle:title
                                               message:message
                                               preferredStyle:UIAlertControllerStyleAlert];

         UIAlertAction *okAction = [UIAlertAction
                                    actionWithTitle:NSLocalizedString(@"OK", @"OK action")
                                    style:UIAlertActionStyleCancel
                                    handler:^(UIAlertAction *action)
                                    {
                                        NSLog(@"OK action");
                                    }];

        [alertController addAction:okAction];

         dispatch_async(dispatch_get_main_queue(), ^{
             [_activityView stopAnimating];
             [self presentViewController:alertController animated:YES completion:nil];
         });
     }];
}

- (void)animateSavedVideoToCollection {
    [self hideCreationToolButtonsAndShiftVideoPlayer];
}


#pragma mark
#pragma mark <UICollectionViewDataSource>

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    
    if (collectionView.tag == 1){
        return _filters.count;
    }else{
        return [self savedVideos].count;
    }
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {

    TocaFilter *filterItem = [[TocaFilter alloc] initAtIndex:indexPath.item];
    
    CustomCollectionCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
    
    // Configure the cell
    //filterCollectionView is tag 1
    if (collectionView.tag == 1){
        cell.textLabel.text = @"";
        cell.textLabel.backgroundColor = [UIColor clearColor];
        cell.imageView.image = [filterItem filterIcon];
        cell.imageView.backgroundColor = [UIColor colorWithRed:(86.0/255.0) green:(223.0/255.0) blue:(219.0/255.0) alpha:1.0];
        cell.backgroundColor = [UIColor colorWithRed:(86.0/255.0) green:(223.0/255.0) blue:(219.0/255.0) alpha:1.0];
    }else{
        //savedVideosCollectionView is tag 2
        NSString *videoPath = _savedVideos[indexPath.item];
        NSString *videoName = [videoPath lastPathComponent];
        cell.textLabel.text = videoName;
    }
    
    return cell;
}

#pragma mark <UICollectionViewDelegate>

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    
    if (collectionView.tag == 1){
        
        if(selectedIndex != indexPath.item){
            
            if (_faceView) {
                [_faceView removeFromSuperview];
                _faceView = nil;
            }
            
            _isUserInterfaceElementVideo = NO;
            if(_previewView) {
                [_previewView removeFromSuperview];
                _previewView = nil;
            }
            
            videoCamera.delegate = nil;
            if(_animatedImageView) {
                _animatedImageView = nil;
            }
            
            [videoCamera removeAllTargets];
            [_filter removeAllTargets];
            
            selectedIndex = indexPath.item;
            selectedFilter = [[TocaFilter alloc] initAtIndex:indexPath.item];
            
            [self startVideoFilter];
            
//            _isFaceSwitched = YES;
//            [self facesSwitched];
            
            
        }
    
    }else{
        //savedVideosCollectionView is tag 2
        NSString *videoPath = _savedVideos[indexPath.item];
        NSString *pathToMovie = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Documents/%@", [videoPath lastPathComponent]]];
        
        _videoPlayerURL = [NSURL URLWithString:[NSString stringWithFormat:@"file://%@", pathToMovie]];
        
        // create an AVPlayer
        AVPlayer *player = [AVPlayer playerWithURL:_videoPlayerURL];
        
        // create a player view controller
        AVPlayerViewController *controller = [[AVPlayerViewController alloc]init];
        controller.player = player;
        [self presentViewController:controller animated:YES completion:^{
            [player play];
        }];
    }
}


- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
    
    
}

- (void)collectionView:(UICollectionView *)collectionView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    
    
}

- (void)collectionView:(UICollectionView *)collectionView didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    
    
}

// utility routing used during image capture to set up capture orientation
- (AVCaptureVideoOrientation)avOrientationForDeviceOrientation:(UIDeviceOrientation)deviceOrientation {
    AVCaptureVideoOrientation result = deviceOrientation;
    if ( deviceOrientation == UIDeviceOrientationLandscapeLeft )
        result = AVCaptureVideoOrientationLandscapeRight;
    else if ( deviceOrientation == UIDeviceOrientationLandscapeRight )
        result = AVCaptureVideoOrientationLandscapeLeft;
    
    return result;
}

#pragma mark - Face Detection Delegate Callback
- (void)willOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer {

    if([selectedFilter filterType] == FilterTypeFaceTracking) {
        if (!faceThinking) {
            CFAllocatorRef allocator = CFAllocatorGetDefault();
            CMSampleBufferRef sbufCopyOut;
            CMSampleBufferCreateCopy(allocator,sampleBuffer,&sbufCopyOut);
            [self performSelectorInBackground:@selector(grepFacesForSampleBuffer:) withObject:CFBridgingRelease(sbufCopyOut)];
        }
    }
}

- (void)grepFacesForSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    faceThinking = TRUE;
//    NSLog(@"Faces thinking");
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    CIImage *convertedImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer options:(__bridge NSDictionary *)attachments];
    
    if (attachments)
        CFRelease(attachments);
    NSDictionary *imageOptions = nil;
    UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
    int exifOrientation;
    
    /* kCGImagePropertyOrientation values
     The intended display orientation of the image. If present, this key is a CFNumber value with the same value as defined
     by the TIFF and EXIF specifications -- see enumeration of integer constants.
     The value specified where the origin (0,0) of the image is located. If not present, a value of 1 is assumed.
     
     used when calling featuresInImage: options: The value for this key is an integer NSNumber from 1..8 as found in kCGImagePropertyOrientation.
     If present, the detection will be done based on that orientation but the coordinates in the returned features will still be based on those of the image. */
    
    enum {
        PHOTOS_EXIF_0ROW_TOP_0COL_LEFT			= 1, //   1  =  0th row is at the top, and 0th column is on the left (THE DEFAULT).
        PHOTOS_EXIF_0ROW_TOP_0COL_RIGHT			= 2, //   2  =  0th row is at the top, and 0th column is on the right.
        PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT      = 3, //   3  =  0th row is at the bottom, and 0th column is on the right.
        PHOTOS_EXIF_0ROW_BOTTOM_0COL_LEFT       = 4, //   4  =  0th row is at the bottom, and 0th column is on the left.
        PHOTOS_EXIF_0ROW_LEFT_0COL_TOP          = 5, //   5  =  0th row is on the left, and 0th column is the top.
        PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP         = 6, //   6  =  0th row is on the right, and 0th column is the top.
        PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM      = 7, //   7  =  0th row is on the right, and 0th column is the bottom.
        PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM       = 8  //   8  =  0th row is on the left, and 0th column is the bottom.
    };
    
    BOOL isUsingFrontFacingCamera = FALSE;
    AVCaptureDevicePosition currentCameraPosition = [videoCamera cameraPosition];
    
    if (currentCameraPosition != AVCaptureDevicePositionBack)
    {
        isUsingFrontFacingCamera = TRUE;
    }
    
    switch (curDeviceOrientation) {
        case UIDeviceOrientationPortraitUpsideDown:  // Device oriented vertically, home button on the top
            exifOrientation = PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM;
            break;
        case UIDeviceOrientationLandscapeLeft:       // Device oriented horizontally, home button on the right
            if (isUsingFrontFacingCamera)
                exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
            else
                exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
            break;
        case UIDeviceOrientationLandscapeRight:      // Device oriented horizontally, home button on the left
            if (isUsingFrontFacingCamera)
                exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
            else
                exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
            break;
        case UIDeviceOrientationPortrait:            // Device oriented vertically, home button on the bottom
        default:
            exifOrientation = PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP;
            break;
    }
    
    imageOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:exifOrientation] forKey:CIDetectorImageOrientation];
    
//    NSLog(@"Face Detector %@", [_faceDetector description]);
//    NSLog(@"converted Image %@", [convertedImage description]);
    NSArray *features = [_faceDetector featuresInImage:convertedImage options:imageOptions];
    
    
    // get the clean aperture
    // the clean aperture is a rectangle that defines the portion of the encoded pixel dimensions
    // that represents image data valid for display.
    CMFormatDescriptionRef fdesc = CMSampleBufferGetFormatDescription(sampleBuffer);
    CGRect clap = CMVideoFormatDescriptionGetCleanAperture(fdesc, false /*originIsTopLeft == false*/);
    
    [self GPUVCWillOutputFeatures:features forClap:clap andOrientation:curDeviceOrientation];
    
    faceThinking = FALSE;
    
}

- (void)GPUVCWillOutputFeatures:(NSArray*)featureArray forClap:(CGRect)clap
                 andOrientation:(UIDeviceOrientation)curDeviceOrientation {
   
        dispatch_async(dispatch_get_main_queue(), ^{
            
            CGRect previewBox = _filteredVideoView.bounds;
            
//            if (featureArray == nil && _faceView) {
//                [_faceView removeFromSuperview];
//                _faceView = nil;
//            }

            for ( CIFaceFeature *faceFeature in featureArray) {
                //Update face bounds for iOS Coordinate System
                CGRect faceRect = [faceFeature bounds];
                
                if(currentInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) {
                    //invert for left orientation
                    faceRect = CGRectMake(previewBox.size.width - faceRect.origin.x, previewBox.size.height - faceRect.origin.y, faceRect.size.width, faceRect.size.height);
                }
                
                if (_faceView) {
                    [_faceView removeFromSuperview];
                    _faceView =  nil;
                }
                
                CGFloat widthScaleBy = (previewBox.size.width / clap.size.width) ;
                CGFloat heightScaleBy = (previewBox.size.height / clap.size.height) ;

                float originWidth = faceRect.size.width * widthScaleBy;
                float originHeight = faceRect.size.height * heightScaleBy;
                
                faceRect.size.width *= widthScaleBy;
                faceRect.size.height *= heightScaleBy;
                faceRect.size.width *= [selectedFilter animationScale];
                faceRect.size.height *= [selectedFilter animationScale];
                
                faceRect.origin.x *= widthScaleBy;
                faceRect.origin.y *= heightScaleBy;
                
                CGFloat xOffset = faceRect.size.width * [selectedFilter animationXOffset];
                CGFloat yOffset = faceRect.size.height * [selectedFilter animationYOffset];
                
                faceRect.origin.x -= (faceRect.size.width-originWidth)/2;
                faceRect.origin.y -= (faceRect.size.height-originHeight)/2;
                
                faceRect.origin.x += xOffset;
                faceRect.origin.y += yOffset;
                
                
                faceRect = CGRectOffset(faceRect, previewBox.origin.x, previewBox.origin.y);
                float faceOffset = faceRect.origin.y * 0.3;
                
                // orientation change to landscape left
                if(currentInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) {
                    float faceXOffset = faceRect.size.width * 0.4;
                    faceRect = CGRectMake(faceRect.origin.x+faceXOffset, faceRect.origin.y-faceOffset, faceRect.size.width, faceRect.size.height+(faceOffset/2));
                } else {
                     faceRect = CGRectMake(faceRect.origin.x, faceRect.origin.y-faceOffset, faceRect.size.width, faceRect.size.height+(faceOffset/2));
                }
                
                _faceView = [[UIView alloc] initWithFrame:faceRect];
//                _faceView.layer.borderColor = [[UIColor redColor] CGColor];
//                _faceView.layer.borderWidth = 1;
                
                faceCGRect = faceRect;
                
                if(_isUserInterfaceElementVideo) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"updateFaceTrackingFrame" object:self];
                }

                [_filteredVideoView addSubview:_faceView];
            }
        });
    
}


//-(void)facesSwitched{
//    if (!_isFaceSwitched) {
//        _isFaceSwitched = YES;
//        [videoCamera setDelegate:nil];
//        if (_faceView) {
//            [_faceView removeFromSuperview];
//            _faceView = nil;
//        }
//    }else{
////        [videoCamera setDelegate:self];
//        _isFaceSwitched = NO;
//    }
//}

- (void)updateFaceTrackingFrame:(NSNotification *)notification {
    _animatedImageView.frame = faceCGRect;
}


#pragma mark - UIGestures For Sticker Filter

- (void)dragSticker:(UIPanGestureRecognizer *) uiPanGestureRecognizer {
    NSLog(@"drag sticker");
    
    if([uiPanGestureRecognizer state] == UIGestureRecognizerStateBegan) {
        initialStickerDragPoint = uiPanGestureRecognizer.view.center;
        lastStickerDragPoint = uiPanGestureRecognizer.view.center;
    
    } else if( [uiPanGestureRecognizer state] == UIGestureRecognizerStateEnded ) {
    
    } else if([uiPanGestureRecognizer state] == UIGestureRecognizerStateChanged ){
        CGPoint translation = [uiPanGestureRecognizer translationInView:uiPanGestureRecognizer.view.superview];
        uiPanGestureRecognizer.view.center = CGPointMake(lastStickerDragPoint.x + translation.x, lastStickerDragPoint.y + translation.y);
        
        NSLog(@"%1f %1f", uiPanGestureRecognizer.view.frame.origin.x, uiPanGestureRecognizer.view.frame.origin.y);
        
        faceCGRect = uiPanGestureRecognizer.view.frame;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"updateFaceTrackingFrame" object:self];
    }
}


#pragma mark - <UITextField Delegate>

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if([_videoNameLabel.text isEqualToString:@""]) {
        
        UIAlertController *alertController = [UIAlertController
                                              alertControllerWithTitle:nil
                                              message:@"Please name your video"
                                              preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"OK", @"OK action")
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction *action)
                                   {
                                       NSLog(@"OK action");
                                   }];
        
        [alertController addAction:okAction];
        [self presentViewController:alertController animated:YES completion:nil];
        
        return NO;
    } else {
        [self saveVideoToCameraRoll];
        [textField resignFirstResponder];
        return YES;
    }
}


#pragma mark - Orientation

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationLandscapeRight);
    
}

- (void)deviceOrientationDidChange:(NSNotification*)notification {
    NSString *notificationName = [notification name];
    if ([notificationName isEqualToString:UIDeviceOrientationDidChangeNotification]) {
        UIDeviceOrientation deviceOrientation = (UIDeviceOrientation)[[UIDevice currentDevice] orientation];
        [self setOrientationOfVideoCamera:deviceOrientation];
    }
}

- (void)setOrientationOfVideoCamera:(UIDeviceOrientation)orientation {

    UIInterfaceOrientation newOrientation;
    switch (orientation) {
        case UIDeviceOrientationPortrait:
            newOrientation = UIInterfaceOrientationPortrait;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            newOrientation = UIInterfaceOrientationPortraitUpsideDown;
            break;
        case UIDeviceOrientationLandscapeLeft:
            newOrientation = UIInterfaceOrientationLandscapeRight;
            break;
        case UIDeviceOrientationLandscapeRight:
            newOrientation = UIInterfaceOrientationLandscapeLeft;
            break;
        default:
            newOrientation = [UIApplication sharedApplication].statusBarOrientation;
    }
    
    currentInterfaceOrientation = newOrientation;
    videoCamera.outputImageOrientation = newOrientation;
}
    

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
