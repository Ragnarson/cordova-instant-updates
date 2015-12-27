//
//  CodeUpdater.m
//  HelloCordova
//
//  Created by Pawel Urbanek on 06/12/15.
//
//

#import "CodeUpdater.h"
#import "AFNetworking.h"
#import "SSZipArchive.h"

static BOOL DEV_MODE = false;
static NSString *API_URL = @"http://localhost:4567/";
static NSString *VERSION_KEY = @"currentVersion";

@implementation CodeUpdater {
    NSFileManager *_fileManager;
    AFHTTPRequestOperationManager *_http;
    NSString *_download_url;
    NSNumber *_version;
    CDVViewController *_viewController;
}

    - (instancetype)initWithViewController:(CDVViewController *)viewController {
        _fileManager = [NSFileManager defaultManager];
        _http = [AFHTTPRequestOperationManager manager];
        _http.requestSerializer = [AFJSONRequestSerializer serializer];
        _http.requestSerializer.timeoutInterval = 15;
        _viewController = viewController;
        self = [super init];
        return self;
    }

    - (void)call {
        if(DEV_MODE) {
            [self copyBundleAssets];
        } else {
            [self copyAssetsIfMissing];
            [self checkForUpdates];
        }
    }

    - (void) copyAssetsIfMissing {
        BOOL assetsExists = [_fileManager fileExistsAtPath:[self writableAssetsPath]];
        if(!assetsExists) {
            [self copyBundleAssets];
        }
    }

    - (void)copyBundleAssets {
        NSLog(@"INFO - copying assets from app bundle writable path");
        [_fileManager removeItemAtPath:[self writableAssetsPath] error:nil];
        [_fileManager copyItemAtPath:[self bundleAssetsPath] toPath:[self writableAssetsPath] error:nil];
    }

   - (NSString *)writableAssetsPath {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths firstObject];
        [self addSkipBackupAttributeToItemAtURL:[NSURL fileURLWithPath:documentsDirectory]];
        return [documentsDirectory stringByAppendingPathComponent:@"/www"];
    }

    - (NSString *)bundleAssetsPath {
        return [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"www"];
    }

    - (void)addSkipBackupAttributeToItemAtURL:(NSURL *)URL {
        NSError *error = nil;
        [URL setResourceValue: [NSNumber numberWithBool: YES] forKey: NSURLIsExcludedFromBackupKey error: &error];
    }

    - (void) checkForUpdates {
        [_http GET:API_URL parameters: nil success:^(AFHTTPRequestOperation *operation, id response) {
            _version = ((NSDictionary *)response)[@"version"];
            _download_url = ((NSDictionary *)response)[@"url"];
            if(_version != (id)[NSNull null] && _download_url != (id)[NSNull null]) {
                if([_version integerValue] > [[self currentVersion] integerValue]) {
                    [self fetchNewVersion];
                } else {
                    NSLog(@"INFO - Version %@ is up to date", [self currentVersion]);
                }
                } else {
                  NSLog(@"INFO - updates api doesn't have any version info. Currently used version is %@", [self currentVersion]);
                }
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            NSLog(@"ERROR: %@", error);
        }];
    }

    - (void) fetchNewVersion {
        UIAlertView *popupDownloading = [[UIAlertView alloc] initWithTitle:@"Update"
                                                             message:@"Your app is being updated."
                                                             delegate:nil
                                                             cancelButtonTitle:nil
                                                             otherButtonTitles:nil];
        
        NSLog(@"INFO - Downloading version %@ started", _version);
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:_download_url]];
        AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];

        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *path = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"package.zip"];
        operation.outputStream = [NSOutputStream outputStreamToFileAtPath:path append:NO];

        [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
            NSLog(@"INFO - Downloading version %@ to %@ completed", _version, path);
            NSString *zipPath = path;
            NSString *destinationPath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@""];
            
            [SSZipArchive unzipFileAtPath:zipPath toDestination:destinationPath];
            [self setCurrentVersion:_version];
            [[NSURLCache sharedURLCache] removeAllCachedResponses];
            [_viewController.webView reload];
            [popupDownloading dismissWithClickedButtonIndex:0 animated:YES];
            UIAlertView *popupCompleted = [[UIAlertView alloc] initWithTitle:@"Update"
                                                               message:@"Your app has been updated."
                                                               delegate:nil
                                                               cancelButtonTitle:@"OK"
                                                               otherButtonTitles:nil];
            [popupCompleted show];
            NSLog(@"INFO - WebView reloaded with a new version: %@", _version);
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            NSLog(@"ERROR: %@", error);
            [popupDownloading dismissWithClickedButtonIndex:0 animated:YES];
        }];
  
        [operation start];
     }

    - (NSNumber *) currentVersion {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if(![defaults integerForKey:VERSION_KEY]) {
            [defaults setInteger:1 forKey:VERSION_KEY];
        }
        
        return @([defaults integerForKey:VERSION_KEY]);
    }

    - (void) setCurrentVersion:(NSNumber *) version {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setInteger:[version integerValue] forKey:VERSION_KEY];
        [defaults synchronize];
    }

@end
