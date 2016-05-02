//
//  ViewController.m
//  TocaBocaVideoRecorder
//
//  Created by Ben Honig on 4/22/16.
//  Copyright © 2016 Gramercy Tech. All rights reserved.
//

#import "ViewController.h"
#import "CustomCollectionCell.h"

static CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};

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
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateFaceTrackingFrame:)
                                                 name:@"updateFaceTrackingFrame"
                                               object:nil];
    
//    NSArray *filterList = [[[TocaFilter alloc] init] filterList];
//    NSLog(@"filter %@", filterList);
//    
    
    
    _isRecording = false;
    selectedIndex = 0;
    
    faceCGRect = CGRectMake(0, 0, 100, 100);
    
    self.filterCollectionView.allowsSelection = YES;
    self.filterCollectionView.tag = 1;
    self.savedVideosCollectionView.allowsSelection = YES;
    self.savedVideosCollectionView.tag = 2;
   
    _savedVideos = [self savedVideos];
    
//    _filters = @[@"Bugs", @"Mouth", @"Cloud"];
    _filters = [[[TocaFilter alloc] initAtIndex:-1] filterList];
    
    // removing original filters
    //@"Sepia", @"BW", @"Sketch", @"Invert", @"Cartoon", @"Miss Etikate", @"Amatorka",
    
    // They want video output to be 16:9
    videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset1280x720 cameraPosition:AVCaptureDevicePositionFront];
//    videoCamera.horizontallyMirrorFrontFacingCamera = NO;
//    videoCamera.horizontallyMirrorRearFacingCamera = NO;
    //videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    videoCamera.outputImageOrientation = UIInterfaceOrientationMaskLandscape;

    [videoCamera setHorizontallyMirrorFrontFacingCamera:NO];
    
    _filter = [[GPUImageFilter alloc] init];
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
    
}

- (void)updateFaceTrackingFrame:(NSNotification *)notification {
    // get the correct ratio for the image based on face tracking
    
    //NSLog(@"old height: %1.3f old width: %1.3f", faceCGRect.size.height, faceCGRect.size.width);
    
//    int width = [selectedFilter animationWidth];
//    int height = [selectedFilter animationHeight];
    
   // NSLog(@"w: %d h: %d", width, height);
    
//    float newRatio = faceCGRect.size.height / height;
    
   // NSLog(@"ratio: %1.3f ", newRatio);
//    float newWidth = width * newRatio;
   // NSLog(@"height: %1.3f width: %1.3f", faceCGRect.size.height, newWidth);
//
//    _animatedImageView.frame = CGRectMake(faceCGRect.origin.x, faceCGRect.origin.y, newWidth, faceCGRect.size.height);
    _animatedImageView.frame = faceCGRect;
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

- (IBAction)recordStartStop:(id)sender{
    
    AVCaptureDevicePosition currentCameraPosition = [videoCamera cameraPosition];
    
    //record the video
    if (_isRecording){
        //stop recording
        _isRecording = false;
        
        //[_recordButton setTitle:@"RECORD" forState:UIControlStateNormal];
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
            
            
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^
             {
                 NSURL *videoURL = [NSURL URLWithString:fileSavedPath];
                 NSLog(@"photo library %@", videoURL);
                 
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
                     [self presentViewController:alertController animated:YES completion:nil];
                     [self resetVideoCamera];
                 });
                 
                 fileSavedPath = nil;
                 
             }];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [_activityView stopAnimating];
                [_activityView removeFromSuperview];
                [weakSelf.savedVideosCollectionView reloadData];
                
                //save to photo roll
                
                NSLog(@"completed");
            });
        }];
    }else{
        
        _isRecording = true;

        [_recordButton setImage:[UIImage imageNamed:@"Stop.png"] forState:UIControlStateNormal];
        [_recordButton setImage:[UIImage imageNamed:@"StopPress.png"] forState:UIControlStateHighlighted];
        [_recordButton setImage:[UIImage imageNamed:@"StopPress.png"] forState:UIControlStateHighlighted];
        
        videoCamera = nil;
        videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset1280x720 cameraPosition:currentCameraPosition];
        if ([[UIDevice currentDevice] orientation] == UIDeviceOrientationLandscapeLeft) {
            videoCamera.outputImageOrientation = UIInterfaceOrientationLandscapeRight;
        }else if ([[UIDevice currentDevice] orientation] == UIDeviceOrientationLandscapeRight) {
            videoCamera.outputImageOrientation = UIInterfaceOrientationLandscapeLeft;
        }

        //stored in Documents which can  be accessed by iTunes (this can change)
        NSString *pathToMovie = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Documents/Toca-%@.m4v", [self videoFileName:6]]];
        fileSavedPath = pathToMovie;
        unlink([pathToMovie UTF8String]); // If a file already exists, AVAssetWriter won't let you record new frames, so delete the old movie
        NSURL *movieURL = [NSURL fileURLWithPath:pathToMovie];
        _movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:CGSizeMake(1280.0, 720.0)];
        _movieWriter.encodingLiveVideo = YES;
        //    movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:CGSizeMake(640.0, 480.0)];
        //    movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:CGSizeMake(720.0, 1280.0)];
        //    movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:CGSizeMake(1080.0, 1920.0)];
        
       // if (_isUserInterfaceElementVideo) {
            _filter = [[GPUImageSaturationFilter alloc] init];
            [(GPUImageSaturationFilter *)_filter setSaturation:1.0];
            GPUImageAlphaBlendFilter *blendFilter = [[GPUImageAlphaBlendFilter alloc] init];
            blendFilter.mix = 1.0;
            
            [videoCamera addTarget:_filter];

 
            UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, _filteredVideoView.frame.size.width, _filteredVideoView.frame.size.height)];
            contentView.backgroundColor = [UIColor clearColor];
            
            
            _animatedImageView = [[UIImageView alloc] initWithFrame:_animatedImageView.frame];
            
//            if( [selectedFilter filterType] == FilterTypeFaceTracking) {
                [videoCamera setDelegate:self];
//            } else {
//                [videoCamera setDelegate:nil];
//            }
            
            _animatedImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"%@00000.png", [selectedFilter animationImagePrefix]]];
            
            [contentView addSubview:_animatedImageView];
            
            uiElementInput = [[GPUImageUIElement alloc] initWithView:contentView];
            //contentView = nil;
        
            
            [_filter addTarget:blendFilter];
            [uiElementInput addTarget:blendFilter];
            
            __unsafe_unretained GPUImageUIElement *weakUIElementInput = uiElementInput;
            __block int indexItem = 0;
            __unsafe_unretained UIImageView *weakImageView = _animatedImageView;
            __block TocaFilter *weakFilter = selectedFilter;
            [_filter setFrameProcessingCompletionBlock:^(GPUImageOutput * filter, CMTime frameTime){
               
//                if([weakFilter filterType] != FilterTypeSticker) {
                if([weakFilter animationFramesAmount] > 0) {
                    if (indexItem > [weakFilter animationFramesAmount]) {
                        indexItem = 0;
                    } else {
                        indexItem++;
                    }
                    UIImage *image = [UIImage imageNamed:[NSString stringWithFormat:@"%@%05d.png", [weakFilter animationImagePrefix], indexItem]];
                    weakImageView.image = image;
                    image = nil;
//                }
                }
                [weakUIElementInput update];
            }];
            
            [blendFilter addTarget:_movieWriter];
            [blendFilter addTarget:_filteredVideoView];
            
            
//        }else{
//            [videoCamera addTarget:_filter];
//            
//            [_filter addTarget:_movieWriter];
//            [_filter addTarget:_filteredVideoView];
//            
//            //_filteredVideoView.fillMode = kGPUImageFillModeStretch;
//        }
        
        [videoCamera stopCameraCapture];
        [videoCamera startCameraCapture];
        
        double delayToStartRecording = 0.5;
        dispatch_time_t startTime = dispatch_time(DISPATCH_TIME_NOW, delayToStartRecording * NSEC_PER_SEC);
        dispatch_after(startTime, dispatch_get_main_queue(), ^(void){
            NSLog(@"Start recording");
            
            videoCamera.audioEncodingTarget = _movieWriter;
            [_movieWriter startRecording];
        });
    }
}

- (void)playVideo{
    
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
    
    //filterCollectionView is tag 1
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
            
            
            _filter = [[GPUImageSaturationFilter alloc] init];
            [(GPUImageSaturationFilter *)_filter setSaturation:1.0];
            GPUImageAlphaBlendFilter *blendFilter = [[GPUImageAlphaBlendFilter alloc] init];
            blendFilter.mix = 1.0;
            
            [videoCamera addTarget:_filter];
            
            
            UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(_filteredVideoView.frame.origin.x, _filteredVideoView.frame.origin.y, _filteredVideoView.frame.size.width, _filteredVideoView.frame.size.height)];
            
            contentView.backgroundColor = [UIColor clearColor];
            
            
            switch ([selectedFilter filterType]) {
                case FilterTypeReset:
                    NSLog(@"reset select");
                    
                    float height = 0;
                    float width = 0;
                    float framex = 0;
                    float framey = 0;
                    
                    videoCamera.delegate = nil;
                    _isUserInterfaceElementVideo = NO;
                    
                    uiElementInput = [[GPUImageUIElement alloc] initWithView:contentView];
                    break;
                
                case FilterTypeSticker:
                    NSLog(@"sticker select");
                    videoCamera.delegate = nil;
                    _isUserInterfaceElementVideo = NO;
                    
                    height = [selectedFilter animationHeight];
                    width = [selectedFilter animationWidth];
                    
                    NSLog(@"height: %1f width %1f ", height, width);
                    
                    framex = ((contentView.frame.size.width - width) / 2);
                    framey = ((contentView.frame.size.height - height) / 2);
                    
                    _previewView = [[UIView alloc] initWithFrame:CGRectMake(_filteredVideoView.frame.origin.x, _filteredVideoView.frame.origin.y, _filteredVideoView.frame.size.width, _filteredVideoView.frame.size.height)];
                    
                    _previewView.backgroundColor = [UIColor clearColor];
                    _animatedImageView = [[UIImageView alloc] initWithFrame:CGRectMake(framex, framey, width, height)];
                    
                    _animatedImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"%@00000.png", [selectedFilter animationImagePrefix]]];
                    [contentView addSubview:_animatedImageView];
                    
                    uiElementInput = [[GPUImageUIElement alloc] initWithView:contentView];
                    break;
                    
                case FilterTypeFrame:
                    NSLog(@"frame select");
                    videoCamera.delegate = nil;
                    _isUserInterfaceElementVideo = NO;
                    
                    _animatedImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, _filteredVideoView.frame.size.width, _filteredVideoView.frame.size.height)];
                    _animatedImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"%@00000.png", [selectedFilter animationImagePrefix]]];
                    
                    [contentView addSubview:_animatedImageView];
                    
                    uiElementInput = [[GPUImageUIElement alloc] initWithView:contentView];
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
                    
                    uiElementInput = [[GPUImageUIElement alloc] initWithView:contentView];
                    break;
                    
                default:
                    NSLog(@"default select");
                    _isUserInterfaceElementVideo = NO;
                    videoCamera.delegate = nil;
                    uiElementInput = [[GPUImageUIElement alloc] initWithView:contentView];
                    break;
            }
            
            
            if([selectedFilter filterType] == FilterTypeSticker) {
            
//                NSMutableArray *images = [[NSMutableArray alloc] init];
//                for (int i = 0; i < ([selectedFilter animationFramesAmount]+1); i++) {
//                    UIImage *image = [UIImage imageNamed:[NSString stringWithFormat:@"%@%05d.png",[selectedFilter animationImagePrefix], i]];
//                    [images addObject:image];
//                    image = nil;
//                }
//                _animatedImageView.animationImages = images;
//
                UIImageView *testImage = [[UIImageView alloc] initWithFrame:_animatedImageView.frame];
                testImage.backgroundColor = [UIColor clearColor];
                
                
                UIPanGestureRecognizer *dragRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragSticker:)];
                testImage.userInteractionEnabled = YES;
                testImage.gestureRecognizers = @[dragRecognizer];
                
                [_previewView addSubview:testImage];
                testImage = nil;
                [self.view addSubview:_previewView];
                
//                [_animatedImageView startAnimating];
            }
            
            
            contentView = nil;
            [_filter addTarget:blendFilter];
            [uiElementInput addTarget:blendFilter];
            
            [blendFilter addTarget:_filteredVideoView];
            
            __unsafe_unretained GPUImageUIElement *weakUIElementInput = uiElementInput;
            __unsafe_unretained UIImageView *weakanimatedView = _animatedImageView;
            __block int indexItem = 0;
            __block TocaFilter *weakFilter = selectedFilter;
            [_filter setFrameProcessingCompletionBlock:^(GPUImageOutput * filter, CMTime frameTime){
                
                 if([weakFilter animationFramesAmount] > 0) {
                    if (indexItem > [weakFilter animationFramesAmount]) {
                        indexItem = 0;
                    } else {
                        indexItem++;
                    }
                    UIImage *image = [UIImage imageNamed:[NSString stringWithFormat:@"%@%05d.png", [weakFilter animationImagePrefix], indexItem]];
                    weakanimatedView.image = image;
                    image = nil;
                 }
       
                [weakUIElementInput update];
                
            }];
                
                
//            _isFaceSwitched = YES;
//            [self facesSwitched];
        //}
            [videoCamera stopCameraCapture];
            [videoCamera startCameraCapture];
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
- (AVCaptureVideoOrientation)avOrientationForDeviceOrientation:(UIDeviceOrientation)deviceOrientation
{
    AVCaptureVideoOrientation result = deviceOrientation;
    if ( deviceOrientation == UIDeviceOrientationLandscapeLeft )
        result = AVCaptureVideoOrientationLandscapeRight;
    else if ( deviceOrientation == UIDeviceOrientationLandscapeRight )
        result = AVCaptureVideoOrientationLandscapeLeft;
    return result;
}

#pragma mark - Face Detection Delegate Callback
- (void)willOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer{

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
                 andOrientation:(UIDeviceOrientation)curDeviceOrientation
{
   
        dispatch_async(dispatch_get_main_queue(), ^{
            //NSLog(@"Did receive array");
           
        
            CGRect previewBox = _filteredVideoView.bounds;
            
            //NSLog(@"preview %1.f %1.f %1.f %1.f", previewBox.origin.x, previewBox.origin.y, previewBox.size.height, previewBox.size.width);
            
            if (featureArray == nil && _faceView) {
                [_faceView removeFromSuperview];
                _faceView = nil;
            }
            
            
            for ( CIFaceFeature *faceFeature in featureArray) {
                
                // find the correct position for the square layer within the previewLayer
                // the feature box originates in the bottom left of the video frame.
                // (Bottom right if mirroring is turned on)
                //NSLog(@"%@", NSStringFromCGRect([faceFeature bounds]));
                
                //Update face bounds for iOS Coordinate System
                CGRect faceRect = [faceFeature bounds];
                
                CGFloat widthScaleBy = previewBox.size.width / clap.size.width;
                CGFloat heightScaleBy = previewBox.size.height / clap.size.height;
                NSLog(@"ratiowidth: %1f  ratioheight:  %1f", widthScaleBy, heightScaleBy);
                faceRect.size.width *= widthScaleBy;
                faceRect.size.height *= heightScaleBy;
                faceRect.origin.x *= widthScaleBy;
                faceRect.origin.y *= heightScaleBy;
                
                faceRect = CGRectOffset(faceRect, previewBox.origin.x, previewBox.origin.y);
                
                
              
                if (_faceView) {
                    [_faceView removeFromSuperview];
                    _faceView =  nil;
                }
                
                float faceOffset = faceRect.origin.y * 0.25;
                float faceHeightOffset = faceRect.size.height * 0.25;
                NSLog(@"%1f", faceRect.size.height);
                NSLog(@"face offset %1f", faceOffset);
                NSLog(@"face height %1f", faceHeightOffset);
                
            faceRect = CGRectMake(faceRect.origin.x, faceRect.origin.y, faceRect.size.width, faceRect.size.height+faceHeightOffset);
                
                // create a UIView using the bounds of the face
                
                ///
//                float hat_width = 290.0;
//                float hat_height = 281.0; //360
//                float head_start_y = 250.0; //part of hat image is transparent
//                float head_start_x = 78.0;
//                
//                float width = faceRect.size.width * (hat_width / (hat_width - head_start_x));
//                float height = width * hat_height/hat_width;
//                float y = faceRect.origin.y - (height * head_start_y) / hat_height;
//                float x = faceRect.origin.x - (head_start_x * width/hat_width);
//                CGRect newFrame = CGRectMake(x, y, width, height);
                ///
                _faceView = [[UIView alloc] initWithFrame:faceRect];
                
                faceCGRect = faceRect;
                
                if(_isUserInterfaceElementVideo) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"updateFaceTrackingFrame" object:self];
                }
               
                _faceView.layer.borderWidth = 1;
                _faceView.layer.borderColor = [[UIColor redColor] CGColor];
                
                //centerFacePoint = _faceView.center;
                
                // add the new view to create a box around the face
                
                [_filteredVideoView addSubview:_faceView];
            }
        });
    
}


-(void)facesSwitched{
    if (!_isFaceSwitched) {
        _isFaceSwitched = YES;
        [videoCamera setDelegate:nil];
        if (_faceView) {
            [_faceView removeFromSuperview];
            _faceView = nil;
        }
    }else{
//        [videoCamera setDelegate:self];
        _isFaceSwitched = NO;
    }
}


#pragma mark - UIGesturesFor Stickers

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

#pragma mark - 

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
    
    
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
