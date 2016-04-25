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
    
    _isRecording = false;
    
    self.filterCollectionView.allowsSelection = YES;
    self.filterCollectionView.tag = 1;
    self.savedVideosCollectionView.allowsSelection = YES;
    self.savedVideosCollectionView.tag = 2;
   
    _savedVideos = [self savedVideos];
    
    _filters = @[@"Sepia", @"BW", @"Sketch", @"Invert", @"Cartoon", @"Miss Etikate", @"Amatorka", @"Bee (face)"];
    
    videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionBack];
    videoCamera.horizontallyMirrorFrontFacingCamera = NO;
    videoCamera.horizontallyMirrorRearFacingCamera = NO;
    //videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    videoCamera.outputImageOrientation = UIInterfaceOrientationLandscapeLeft;
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
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
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
    
    videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:currentCameraPosition];
    if ([[UIDevice currentDevice] orientation] == UIDeviceOrientationLandscapeLeft) {
        videoCamera.outputImageOrientation = UIInterfaceOrientationLandscapeLeft;
    }else if ([[UIDevice currentDevice] orientation] == UIDeviceOrientationLandscapeRight) {
        videoCamera.outputImageOrientation = UIInterfaceOrientationLandscapeRight;
    }
    videoCamera.horizontallyMirrorFrontFacingCamera = NO;
    videoCamera.horizontallyMirrorRearFacingCamera = NO;
    
    //record the video
    if (_isRecording){
        //stop recording
        _isRecording = false;
        [_recordButton setTitle:@"RECORD" forState:UIControlStateNormal];
        
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
            
            [_activityView stopAnimating];
            [_activityView removeFromSuperview];
            
            [weakSelf.savedVideosCollectionView reloadData];
            NSLog(@"completed");
        }];
    }else{
        _isRecording = true;
        [_recordButton setTitle:@"STOP" forState:UIControlStateNormal];
        
        //stored in Documents which can  be accessed by iTunes (this can change)
        NSString *pathToMovie = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Documents/Toca-%@.m4v", [self videoFileName:6]]];
        unlink([pathToMovie UTF8String]); // If a file already exists, AVAssetWriter won't let you record new frames, so delete the old movie
        NSURL *movieURL = [NSURL fileURLWithPath:pathToMovie];
        _movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:CGSizeMake(640.0, 480.0)];
        _movieWriter.encodingLiveVideo = YES;
        //    movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:CGSizeMake(640.0, 480.0)];
        //    movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:CGSizeMake(720.0, 1280.0)];
        //    movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:CGSizeMake(1080.0, 1920.0)];
        
        if (_isUserInterfaceElementVideo) {
            _filter = [[GPUImageSaturationFilter alloc] init];
            [(GPUImageSaturationFilter *)_filter setSaturation:1.0];
            GPUImageAlphaBlendFilter *blendFilter = [[GPUImageAlphaBlendFilter alloc] init];
            blendFilter.mix = 1.0;
            
            [videoCamera addTarget:_filter];
            
            NSDate *sTime = [NSDate date];
            
            UILabel *timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, 240.0f, 320.0f)];
            timeLabel.font = [UIFont systemFontOfSize:17.0f];
            timeLabel.text = @"Time: 0.0 s";
            timeLabel.textAlignment = NSTextAlignmentCenter;
            timeLabel.backgroundColor = [UIColor clearColor];
            timeLabel.textColor = [UIColor whiteColor];
            
            uiElementInput = [[GPUImageUIElement alloc] initWithView:timeLabel];
            
            [_filter addTarget:blendFilter];
            [uiElementInput addTarget:blendFilter];
            
            [blendFilter addTarget:_filteredVideoView];
            
            __unsafe_unretained GPUImageUIElement *weakUIElementInput = uiElementInput;
            [_filter setFrameProcessingCompletionBlock:^(GPUImageOutput * filter, CMTime frameTime){
                timeLabel.text = [NSString stringWithFormat:@"Time: %f s", -[sTime timeIntervalSinceNow]];
                [UIView animateWithDuration:0.4 delay:0.0 options:UIViewAnimationOptionRepeat|UIViewAnimationOptionRepeat animations:^{
                    timeLabel.frame = CGRectMake(timeLabel.frame.origin.x - 50, timeLabel.frame.origin.y, timeLabel.frame.size.width, timeLabel.frame.size.height);
                } completion:^(BOOL finished) {
                    //completed
                }];
                [weakUIElementInput update];
            }];
            
            [blendFilter addTarget:_movieWriter];
        }else{
            _filter = [[GPUImageSaturationFilter alloc] init];
            [(GPUImageSaturationFilter *)_filter setSaturation:1.0];
            
            [_filter addTarget:_movieWriter];
            [_filter addTarget:_filteredVideoView];
            
            
            [_filter addTarget:_filteredVideoView];
            [videoCamera addTarget:_filter];
            //    _filteredVideoView.fillMode = kGPUImageFillModeStretch;
            //    _filteredVideoView.fillMode = kGPUImageFillModePreserveAspectRatioAndFill;
        }
        
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
    
    CustomCollectionCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
    
    // Configure the cell
    //filterCollectionView is tag 1
    if (collectionView.tag == 1){
        cell.textLabel.text = _filters[indexPath.item];
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
    _isUserInterfaceElementVideo = NO;
    //filterCollectionView is tag 1
    if (collectionView.tag == 1){
        _filter = nil;
        [videoCamera removeAllTargets];
        [_filter removeAllTargets];
        if (indexPath.item == 0){
            //sepia
            _filter = [[GPUImageSepiaFilter alloc] init];
            [videoCamera addTarget:_filter];
            [_filter addTarget:_filteredVideoView];
        }else if(indexPath.item == 1){
            //black and white
            _filter = [[GPUImageGrayscaleFilter alloc] init];
            [videoCamera addTarget:_filter];
            [_filter addTarget:_filteredVideoView];
        }else if(indexPath.item == 2){
            //sketch
            _filter = [[GPUImageSketchFilter alloc] init];
            [videoCamera addTarget:_filter];
            [_filter addTarget:_filteredVideoView];
        }else if(indexPath.item == 3){
            //invert
            _filter = [[GPUImageColorInvertFilter alloc] init];
            [videoCamera addTarget:_filter];
            [_filter addTarget:_filteredVideoView];
        }else if(indexPath.item == 4){
            //cartoon
            _filter= [[GPUImageSmoothToonFilter alloc] init];
            [videoCamera addTarget:_filter];
            [_filter addTarget:_filteredVideoView];
        }else if(indexPath.item == 5){
            //MissEtikate
            _filter = [[GPUImageMissEtikateFilter alloc] init];
            [videoCamera addTarget:_filter];
            [_filter addTarget:_filteredVideoView];

        }else if(indexPath.item == 6){
            //Amatorka
            _filter = [[GPUImageAmatorkaFilter alloc] init];
            [videoCamera addTarget:_filter];
            [_filter addTarget:_filteredVideoView];
        }else if (indexPath.item == 7){
            _isUserInterfaceElementVideo = YES;
            //bee face
            [videoCamera rotateCamera];
            
            _filter = [[GPUImageSaturationFilter alloc] init];
            [(GPUImageSaturationFilter *)_filter setSaturation:1.0];
            GPUImageAlphaBlendFilter *blendFilter = [[GPUImageAlphaBlendFilter alloc] init];
            blendFilter.mix = 1.0;
            
            [videoCamera addTarget:_filter];
            
            NSDate *startTime = [NSDate date];
            
            UILabel *timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, 240.0f, 320.0f)];
            timeLabel.font = [UIFont systemFontOfSize:17.0f];
            timeLabel.text = @"Time: 0.0 s";
            timeLabel.textAlignment = NSTextAlignmentCenter;
            timeLabel.backgroundColor = [UIColor clearColor];
            timeLabel.textColor = [UIColor whiteColor];
            
            uiElementInput = [[GPUImageUIElement alloc] initWithView:timeLabel];
            
            [_filter addTarget:blendFilter];
            [uiElementInput addTarget:blendFilter];
            
            [blendFilter addTarget:_filteredVideoView];
            
            __unsafe_unretained GPUImageUIElement *weakUIElementInput = uiElementInput;
            [_filter setFrameProcessingCompletionBlock:^(GPUImageOutput * filter, CMTime frameTime){
                timeLabel.text = [NSString stringWithFormat:@"Time: %f s", -[startTime timeIntervalSinceNow]];
                [UIView animateWithDuration:0.4 delay:0.0 options:UIViewAnimationOptionRepeat|UIViewAnimationOptionRepeat animations:^{
                    timeLabel.frame = CGRectMake(timeLabel.frame.origin.x - 50, timeLabel.frame.origin.y, timeLabel.frame.size.width, timeLabel.frame.size.height);
                } completion:^(BOOL finished) {
                    //completed
                }];
                [weakUIElementInput update];
            }];
            
            _isFaceSwitched = YES;
            [self facesSwitched];
        }
        [videoCamera stopCameraCapture];
        [videoCamera startCameraCapture];
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
    AVCaptureVideoOrientation result = AVCaptureVideoOrientationPortrait;
    if ( deviceOrientation == UIDeviceOrientationLandscapeLeft )
        result = AVCaptureVideoOrientationLandscapeRight;
    else if ( deviceOrientation == UIDeviceOrientationLandscapeRight )
        result = AVCaptureVideoOrientationLandscapeLeft;
    return result;
}

#pragma mark - Face Detection Delegate Callback
- (void)willOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    if (!faceThinking) {
        CFAllocatorRef allocator = CFAllocatorGetDefault();
        CMSampleBufferRef sbufCopyOut;
        CMSampleBufferCreateCopy(allocator,sampleBuffer,&sbufCopyOut);
        [self performSelectorInBackground:@selector(grepFacesForSampleBuffer:) withObject:CFBridgingRelease(sbufCopyOut)];
    }
}

- (void)grepFacesForSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    faceThinking = TRUE;
    NSLog(@"Faces thinking");
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
    
    NSLog(@"Face Detector %@", [_faceDetector description]);
    NSLog(@"converted Image %@", [convertedImage description]);
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
        NSLog(@"Did receive array");
        
        CGRect previewBox = _filteredVideoView.bounds;
        
        if (featureArray == nil && _faceView) {
            [_faceView removeFromSuperview];
            _faceView = nil;
        }
        
        
        for ( CIFaceFeature *faceFeature in featureArray) {
            
            // find the correct position for the square layer within the previewLayer
            // the feature box originates in the bottom left of the video frame.
            // (Bottom right if mirroring is turned on)
            NSLog(@"%@", NSStringFromCGRect([faceFeature bounds]));
            
            //Update face bounds for iOS Coordinate System
            CGRect faceRect = [faceFeature bounds];
            
            // flip preview width and height
            CGFloat temp = faceRect.size.width;
            faceRect.size.width = faceRect.size.height;
            faceRect.size.height = temp;
            temp = faceRect.origin.x;
            faceRect.origin.x = faceRect.origin.y;
            faceRect.origin.y = temp;
            // scale coordinates so they fit in the preview box, which may be scaled
            CGFloat widthScaleBy = previewBox.size.width / clap.size.height;
            CGFloat heightScaleBy = previewBox.size.height / clap.size.width;
            faceRect.size.width *= widthScaleBy;
            faceRect.size.height *= heightScaleBy;
            faceRect.origin.x *= widthScaleBy;
            faceRect.origin.y *= heightScaleBy;
            
            faceRect = CGRectOffset(faceRect, previewBox.origin.x, previewBox.origin.y);
            
            //faceRect = CGRectOffset(faceRect, previewBox.origin.x + previewBox.size.width - faceRect.size.width - (faceRect.origin.x * 2), previewBox.origin.y);
            
            if (_faceView) {
                [_faceView removeFromSuperview];
                _faceView =  nil;
            }
            
            // create a UIView using the bounds of the face
            //_faceView = [[UIView alloc] initWithFrame:faceRect];
            _faceView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"bee.png"]];
            _faceView.frame = faceRect;
            
            // add a border around the newly created UIView
            //_faceView.layer.borderWidth = 1;
            //_faceView.layer.borderColor = [[UIColor redColor] CGColor];
            
            // add the new view to create a box around the face
            [_filteredVideoView addSubview:_faceView];
            
            switch (curDeviceOrientation) {
                case UIDeviceOrientationPortrait:
                    [_faceView.layer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(-90.))];
                    break;
                case UIDeviceOrientationPortraitUpsideDown:
                    [_faceView.layer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(180.))];
                    break;
                case UIDeviceOrientationLandscapeLeft:
                    [_faceView.layer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(0.))];
                    break;
                case UIDeviceOrientationLandscapeRight:
                    [_faceView.layer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(-90.))];
                    break;
                case UIDeviceOrientationFaceUp:
                case UIDeviceOrientationFaceDown:
                default:
                    break; // leave the layer in its last known orientation
            }
        }
        [CATransaction commit];
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
        [videoCamera setDelegate:self];
        _isFaceSwitched = NO;
    }
}

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
