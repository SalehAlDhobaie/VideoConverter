//
//  VideoConverter.swift
//  Video Converter
//
//  Created by Saleh AlDhobaie on 5/9/16.
//  Copyright © 2016 Saleh AlDhobaie. All rights reserved.
//

import Foundation
import AVFoundation

protocol VideoConverterDelegate : class {
    
    func videoConvertedSuccessfully(let outputVideo: VideoOutput);
    func videoConvertedFailure(let error : NSError, let status: AVAssetExportSessionStatus);
}

struct VideoInput {
    
    let inputVideoURL : NSURL?
    let inputMimeType : String?
}

struct VideoOutput {
    
    let outputVideoURL : NSURL?
    let outputMimeType : String?
    let format : VideoFormat?
    let outputStatus : AVAssetExportSessionStatus = .Unknown
}


enum VideoFormat {
    case MP4
}

enum VideoConvertError : ErrorType {
    
    case NilVideoInput
    
    case VideoTrackNotAvailable
    case AudioTrackNotAvailable
    
    case IssueInsertingVideo
    case IssueInsertingAudio
    
    case ExportError(String)
    
}

class VideoConverter : NSObject {
    
    var videoOutput : VideoOutput? = nil
    
    // default is true if not output file will be timestamp converting
    var autoGenerateIdentifier = true
    //
    var ignoreAudioTrack = true
    
    weak var delegate : VideoConverterDelegate?
    
    override init() {
        
    }
    
    func convertVideo(let videoInput : VideoInput, let format : VideoFormat) throws {
        
        guard let assetUrl = videoInput.inputVideoURL else {
            throw  VideoConvertError.NilVideoInput
        }
        
        let asset : AVURLAsset = AVURLAsset(URL: assetUrl);
        
        // Create the composition and tracks
        let composition = AVMutableComposition()
        
        let videoTrack = composition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID:kCMPersistentTrackID_Invalid)
        
        let audioTrack = composition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        let tracks = asset.tracksWithMediaType(AVMediaTypeVideo)
        
        // Extracting Video
        
        guard let assetVideoTrack = tracks.first else {
            throw VideoConvertError.VideoTrackNotAvailable
        }
        
        // Insert the tracks in the composition's tracks
        do {
            try videoTrack.insertTimeRange(assetVideoTrack.timeRange, ofTrack: assetVideoTrack, atTime: CMTimeMake(0, 1))
        }catch let errorInsertingVideo {
            print(errorInsertingVideo)
            throw VideoConvertError.IssueInsertingVideo
        }
        videoTrack.preferredTransform = assetVideoTrack.preferredTransform;
        
        
        // Extracting Audio 
        guard let assetAudioTrack : AVAssetTrack = asset.tracksWithMediaType(AVMediaTypeAudio).first else {
            throw VideoConvertError.AudioTrackNotAvailable
        }
        

        do {
            try audioTrack.insertTimeRange(assetAudioTrack.timeRange, ofTrack: assetAudioTrack, atTime: CMTimeMake(0, 1))
        }catch let errorInsertingAudio {
            print(errorInsertingAudio)
            throw VideoConvertError.IssueInsertingAudio
        }
        
        
        
        // preparing File Name
        var fileNameOutput : String = "\(NSDate().timeIntervalSinceReferenceDate)"
        if autoGenerateIdentifier {
            fileNameOutput = NSUUID().UUIDString
        }
        
        // Extracting Path
        let outputPath = filePath(fileNameOutput)
        let exportURL : NSURL = NSURL(fileURLWithPath: outputPath).URLByAppendingPathExtension("mp4");
        
        // Export to mp4
        let exportSession : AVAssetExportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough)!
        
        exportSession.outputURL = exportURL
        let startTime = CMTimeMakeWithSeconds(0.0, 0);
        let range : CMTimeRange = CMTimeRangeMake(startTime, asset.duration);
        
        exportSession.timeRange = range;
        exportSession.outputFileType = AVFileTypeMPEG4
        
        exportSession.exportAsynchronouslyWithCompletionHandler {
            
            switch exportSession.status {
            case .Completed:
                let output = exportSession.outputURL!
                self.videoOutput = VideoOutput(outputVideoURL:output , outputMimeType: "video/mp4", format: .MP4);
                
                self.delegate?.videoConvertedSuccessfully(self.videoOutput!);
            case .Failed:
                self.delegate?.videoConvertedFailure(exportSession.error!, status: exportSession.status);
                break
            default :
                break
            }
        }
    }
    
    private func filePath(let fileName : String) -> String {
        return "\(NSHomeDirectory())/Documents/\(fileName)."
    }
    
}



