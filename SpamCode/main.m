//
//  main.m
//  generateSpamCode
//
//  Created by 柯磊 on 2017/7/5.
//  Copyright © 2017年 GAEA. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <stdlib.h>

// 命令行修改工程目录下所有 png 资源 hash 值
// 使用 ImageMagick 进行图片压缩，所以需要安装 ImageMagick，安装方法 brew install imagemagick
// find . -iname "*.png" -exec echo {} \; -exec convert {} {} \;
// or
// find . -iname "*.png" -exec echo {} \; -exec convert {} -quality 95 {} \;

typedef NS_ENUM(NSInteger, GSCSourceType) {
    GSCSourceTypeClass,
    GSCSourceTypeCategory,
};

void recursiveDirectory(NSString *directory, NSArray<NSString *> *ignoreDirNames, void(^handleMFile)(NSString *mFilePath), void(^handleSwiftFile)(NSString *swiftFilePath));
void generateSpamCodeFile(NSString *outDirectory, NSString *mFilePath, GSCSourceType type, NSMutableString *categoryCallImportString, NSMutableString *categoryCallFuncString, NSMutableString *newClassCallImportString, NSMutableString *newClassCallFuncString);
void generateSwiftSpamCodeFile(NSString *outDirectory, NSString *swiftFilePath);
NSString *randomString(NSInteger length);
void handleXcassetsFiles(NSString *directory);
void deleteComments(NSString *directory, NSArray<NSString *> *ignoreDirNames);
void modifyProjectName(NSString *projectDir, NSString *oldName, NSString *newName);
void modifyClassNamePrefix(NSMutableString *projectContent, NSString *sourceCodeDir, NSArray<NSString *> *ignoreDirNames, NSString *oldName, NSString *newName);

NSString *gOutParameterName = nil;
NSString *gSpamCodeFuncationCallName = nil;
NSString *gNewClassFuncationCallName = nil;
NSString *gSourceCodeDir = nil;
static NSString * const kNewClassDirName = @"BaseClass";

#pragma mark  =========== 添加垃圾代码 ==========
NSInteger kSpamCount = 0;//每四个垃圾方法加参数

void addSpamCodeFile(NSString *sourceCodeDir, NSArray<NSString *> *ignoreDirNames);
void creatApiToFile(NSString *sourceCodeDir,NSString *apiName, NSString *paramName,NSString *logName,NSString *filePath, BOOL isHfile);

#pragma mark  =========== 替换API名 ==========
/** 项目中要替换的旧API名 */
NSString *modifyApiLocalAPIList = @"/Users/oneyian/Documents/GitHub/KLGenerateSpamCode/KLGenerateSpamCode/LocalAPIList.plist";
/** 混淆数组，根据里面的字段组成新API名 */
NSString *modifyApiNameList = @"/Users/oneyian/Documents/GitHub/KLGenerateSpamCode/KLGenerateSpamCode/NameList.plist";
/** 已替换的新API名 */
NSString *modifyApiNewAPIList = @"/Users/oneyian/Documents/GitHub/KLGenerateSpamCode/KLGenerateSpamCode/NewAPIList.plist";

void modifyApi(NSString *sourceCodeDir,NSString *oldName,NSString *newName);
void changeAPIName(NSString *sourceCodeDir,NSString *oldName);

#pragma mark - 公共方法

static const NSString *kRandomAlphabet = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
NSString *randomString(NSInteger length) {
    NSMutableString *ret = [NSMutableString stringWithCapacity:length];
    for (int i = 0; i < length; i++) {
        [ret appendFormat:@"%C", [kRandomAlphabet characterAtIndex:arc4random_uniform((uint32_t)[kRandomAlphabet length])]];
    }
    return ret;
}

NSString *randomLetter() {
    return [NSString stringWithFormat:@"%C", [kRandomAlphabet characterAtIndex:arc4random_uniform(52)]];
}

NSRange getOutermostCurlyBraceRange(NSString *string, unichar beginChar, unichar endChar, NSInteger beginIndex) {
    NSInteger braceCount = -1;
    NSInteger endIndex = string.length - 1;
    for (NSInteger i = beginIndex; i <= endIndex; i++) {
        unichar c = [string characterAtIndex:i];
        if (c == beginChar) {
            braceCount = ((braceCount == -1) ? 0 : braceCount) + 1;
        } else if (c == endChar) {
            braceCount--;
        }
        if (braceCount == 0) {
            endIndex = i;
            break;
        }
    }
    return NSMakeRange(beginIndex + 1, endIndex - beginIndex - 1);
}

NSString * getSwiftImportString(NSString *string) {
    NSMutableString *ret = [NSMutableString string];
    
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"^ *import *.+" options:NSRegularExpressionAnchorsMatchLines|NSRegularExpressionUseUnicodeWordBoundaries error:nil];
    
    NSArray<NSTextCheckingResult *> *matches = [expression matchesInString:string options:0 range:NSMakeRange(0, string.length)];
    [matches enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *importRow = [string substringWithRange:obj.range];
        [ret appendString:importRow];
        [ret appendString:@"\n"];
    }];
    
    return ret;
}

BOOL regularReplacement(NSMutableString *originalString, NSString *regularExpression, NSString *newString) {
    __block BOOL isChanged = NO;
    BOOL isGroupNo1 = [newString isEqualToString:@"\\1"];
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:regularExpression options:NSRegularExpressionAnchorsMatchLines|NSRegularExpressionUseUnixLineSeparators error:nil];
    NSArray<NSTextCheckingResult *> *matches = [expression matchesInString:originalString options:0 range:NSMakeRange(0, originalString.length)];
    [matches enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSTextCheckingResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (!isChanged) {
            isChanged = YES;
        }
        if (isGroupNo1) {
            NSString *withString = [originalString substringWithRange:[obj rangeAtIndex:1]];
            [originalString replaceCharactersInRange:obj.range withString:withString];
        } else {
            [originalString replaceCharactersInRange:obj.range withString:newString];
        }
    }];
    return isChanged;
}

void renameFile(NSString *oldPath, NSString *newPath) {
    NSError *error;
    [[NSFileManager defaultManager] moveItemAtPath:oldPath toPath:newPath error:&error];
    if (error) {
        printf("修改文件名称失败。\n  oldPath=%s\n  newPath=%s\n  ERROR:%s\n", oldPath.UTF8String, newPath.UTF8String, error.localizedDescription.UTF8String);
        abort();
    }
}

#pragma mark - 主入口

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSArray<NSString *> *arguments = [[NSProcessInfo processInfo] arguments];
        if (!arguments || arguments.count <= 1) {
            printf("缺少工程目录参数\n");
            return 1;
        }
        if (arguments.count <= 2) {
            printf("缺少任务参数 -spamCodeOut or -handleXcassets or -deleteComments\n");
            return 1;
        }
        
        BOOL isDirectory = NO;
        NSString *outDirString = nil;
        NSArray<NSString *> *ignoreDirNames = nil;
        BOOL needHandleXcassets = NO;
        BOOL needDeleteComments = NO;
        BOOL needModifyAPIName = NO;
        BOOL needOutDirAPIString = NO;
        NSString *oldProjectName = nil;
        NSString *newProjectName = nil;
        NSString *projectFilePath = nil;
        NSString *oldClassNamePrefix = nil;
        NSString *newClassNamePrefix = nil;
        
        NSFileManager *fm = [NSFileManager defaultManager];
        for (NSInteger i = 1; i < arguments.count; i++) {
            NSString *argument = arguments[i];
            if (i == 1) {
                gSourceCodeDir = argument;
                if (![fm fileExistsAtPath:gSourceCodeDir isDirectory:&isDirectory]) {
                    printf("%s不存在\n", [gSourceCodeDir UTF8String]);
                    return 1;
                }
                if (!isDirectory) {
                    printf("%s不是目录\n", [gSourceCodeDir UTF8String]);
                    return 1;
                }
                continue;
            }
            
            if ([argument isEqualToString:@"-handleXcassets"]) {
                needHandleXcassets = YES;
                continue;
            }
            if ([argument isEqualToString:@"-deleteComments"]) {
                needDeleteComments = YES;
                continue;
            }
            if ([argument isEqualToString:@"-modifyProjectName"]) {
                NSString *string = arguments[++i];
                NSArray<NSString *> *names = [string componentsSeparatedByString:@">"];
                if (names.count < 2) {
                    printf("修改工程名参数错误。参数示例：CCApp>DDApp，传入参数：%s\n", string.UTF8String);
                    return 1;
                }
                oldProjectName = names[0];
                newProjectName = names[1];
                if (oldProjectName.length <= 0 || newProjectName.length <= 0) {
                    printf("修改工程名参数错误。参数示例：CCApp>DDApp，传入参数：%s\n", string.UTF8String);
                    return 1;
                }
                continue;
            }
            if ([argument isEqualToString:@"-modifyClassNamePrefix"]) {
                NSString *string = arguments[++i];
                projectFilePath = [string stringByAppendingPathComponent:@"project.pbxproj"];
                if (![fm fileExistsAtPath:string isDirectory:&isDirectory] || !isDirectory
                    || ![fm fileExistsAtPath:projectFilePath isDirectory:&isDirectory] || isDirectory) {
                    printf("修改类名前缀的工程文件参数错误。%s", string.UTF8String);
                    return 1;
                }
                
                string = arguments[++i];
                NSArray<NSString *> *names = [string componentsSeparatedByString:@">"];
                if (names.count < 2) {
                    printf("修改类名前缀参数错误。参数示例：CC>DD，传入参数：%s\n", string.UTF8String);
                    return 1;
                }
                oldClassNamePrefix = names[0];
                newClassNamePrefix = names[1];
                if (oldClassNamePrefix.length <= 0 || newClassNamePrefix.length <= 0) {
                    printf("修改类名前缀参数错误。参数示例：CC>DD，传入参数：%s\n", string.UTF8String);
                    return 1;
                }
                continue;
            }
            if ([argument isEqualToString:@"-spamCodeOut"]) {
                outDirString = arguments[++i];
                if ([fm fileExistsAtPath:outDirString isDirectory:&isDirectory]) {
                    if (!isDirectory) {
                        printf("%s 已存在但不是文件夹，需要传入一个输出文件夹目录\n", [outDirString UTF8String]);
                        return 1;
                    }
                } else {
                    NSError *error = nil;
                    if (![fm createDirectoryAtPath:outDirString withIntermediateDirectories:YES attributes:nil error:&error]) {
                        printf("创建输出目录失败，请确认 -spamCodeOut 之后接的是一个“输出文件夹目录”参数，错误信息如下：\n传入的输出文件夹目录：%s\n%s\n", [outDirString UTF8String], [error.localizedDescription UTF8String]);
                        return 1;
                    }
                }
                
                NSString *newClassOutDirString = [outDirString stringByAppendingPathComponent:kNewClassDirName];
                if ([fm fileExistsAtPath:newClassOutDirString isDirectory:&isDirectory]) {
                    if (!isDirectory) {
                        printf("%s 已存在但不是文件夹\n", [newClassOutDirString UTF8String]);
                        return 1;
                    }
                } else {
                    NSError *error = nil;
                    if (![fm createDirectoryAtPath:newClassOutDirString withIntermediateDirectories:YES attributes:nil error:&error]) {
                        printf("创建输出目录 %s 失败", [newClassOutDirString UTF8String]);
                        return 1;
                    }
                }
                
                i++;
                if (i < arguments.count) {
                    gOutParameterName = arguments[i];
                    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[a-zA-Z]+" options:0 error:nil];
                    if ([regex numberOfMatchesInString:gOutParameterName options:0 range:NSMakeRange(0, gOutParameterName.length)] <= 0) {
                        printf("缺少垃圾代码参数名，或参数名\"%s\"不合法(需要字母开头)\n", [gOutParameterName UTF8String]);
                        return 1;
                    }
                } else {
                    printf("缺少垃圾代码参数名，参数名需要根在输出目录后面\n");
                    return 1;
                }
                
                i++;
                if (i < arguments.count) {
                    gSpamCodeFuncationCallName = arguments[i];
                    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[a-zA-Z]+" options:0 error:nil];
                    if ([regex numberOfMatchesInString:gSpamCodeFuncationCallName options:0 range:NSMakeRange(0, gSpamCodeFuncationCallName.length)] <= 0) {
                        printf("缺少垃圾代码函数调用名，或参数名\"%s\"不合法(需要字母开头)\n", [gSpamCodeFuncationCallName UTF8String]);
                        return 1;
                    }
                }
                
                i++;
                if (i < arguments.count) {
                    gNewClassFuncationCallName = arguments[i];
                    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[a-zA-Z]+" options:0 error:nil];
                    if ([regex numberOfMatchesInString:gNewClassFuncationCallName options:0 range:NSMakeRange(0, gNewClassFuncationCallName.length)] <= 0) {
                        printf("缺少 NewClass 代码函数调用名，或参数名\"%s\"不合法(需要字母开头)\n", [gNewClassFuncationCallName UTF8String]);
                        return 1;
                    }
                }
                continue;
            }
            if ([argument isEqualToString:@"-ignoreDirNames"]) {
                ignoreDirNames = [arguments[++i] componentsSeparatedByString:@","];
                continue;
            }
            if([argument isEqualToString:@"-modifyAPIName"]){
                needModifyAPIName = YES;
                continue;
            }
            if([argument isEqualToString:@"-modifySpamAPI"]){
                needOutDirAPIString = YES;
                continue;
            }
        }
        
        if (needHandleXcassets) {
            @autoreleasepool {
                handleXcassetsFiles(gSourceCodeDir);
            }
            printf("修改 Xcassets 中的图片名称完成\n");
        }
        if (needModifyAPIName){
            printf("正在修改api名称\n");
            @autoreleasepool {
                NSString *path = modifyApiLocalAPIList.mutableCopy;
                NSMutableArray* points = [NSMutableArray arrayWithContentsOfFile:path];
                for(int i = 0;i<points.count;i++){
                    @autoreleasepool {
                        changeAPIName(gSourceCodeDir,points[i]);
                    }
                }
            }
            printf("修改api名称完成\n");
        }
        if (needOutDirAPIString) {
            @autoreleasepool {
                printf("正在生成垃圾API\n");
                addSpamCodeFile(gSourceCodeDir, ignoreDirNames);
            }
            printf("生成垃圾API完成\n");
        }
        if (needDeleteComments) {
            @autoreleasepool {
                deleteComments(gSourceCodeDir, ignoreDirNames);
            }
            printf("删除注释和空行完成\n");
        }
        if (oldProjectName && newProjectName) {
            @autoreleasepool {
                NSString *dir = gSourceCodeDir.stringByDeletingLastPathComponent;
                modifyProjectName(dir, oldProjectName, newProjectName);
            }
            printf("修改工程名完成\n");
        }
        if (oldClassNamePrefix && newClassNamePrefix) {
            printf("开始修改类名前缀...\n");
            @autoreleasepool {
                // 打开工程文件
                NSError *error = nil;
                NSMutableString *projectContent = [NSMutableString stringWithContentsOfFile:projectFilePath encoding:NSUTF8StringEncoding error:&error];
                if (error) {
                    printf("打开工程文件 %s 失败：%s\n", projectFilePath.UTF8String, error.localizedDescription.UTF8String);
                    return 1;
                }
                
                modifyClassNamePrefix(projectContent, gSourceCodeDir, ignoreDirNames, oldClassNamePrefix, newClassNamePrefix);
                
                [projectContent writeToFile:projectFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
            }
            printf("修改类名前缀完成\n");
        }
        if (outDirString) {
            NSMutableString *categoryCallImportString = [NSMutableString string];
            NSMutableString *categoryCallFuncString = [NSMutableString string];
            NSMutableString *newClassCallImportString = [NSMutableString string];
            NSMutableString *newClassCallFuncString = [NSMutableString string];
            
            recursiveDirectory(gSourceCodeDir, ignoreDirNames, ^(NSString *mFilePath) {
                @autoreleasepool {
                    generateSpamCodeFile(outDirString, mFilePath, GSCSourceTypeClass, categoryCallImportString, categoryCallFuncString, newClassCallImportString, newClassCallFuncString);
                    generateSpamCodeFile(outDirString, mFilePath, GSCSourceTypeCategory, categoryCallImportString, categoryCallFuncString, newClassCallImportString, newClassCallFuncString);
                }
            }, ^(NSString *swiftFilePath) {
                @autoreleasepool {
                    generateSwiftSpamCodeFile(outDirString, swiftFilePath);
                }
            });
            
            NSString *fileName = [gOutParameterName stringByAppendingString:@"CallHeader.h"];
            NSString *fileContent = [NSString stringWithFormat:@"%@\n%@return ret;\n}", categoryCallImportString, categoryCallFuncString];
            [fileContent writeToFile:[outDirString stringByAppendingPathComponent:fileName] atomically:YES encoding:NSUTF8StringEncoding error:nil];
            
            fileName = [kNewClassDirName stringByAppendingString:@"CallHeader.h"];
            fileContent = [NSString stringWithFormat:@"%@\n%@return ret;\n}", newClassCallImportString, newClassCallFuncString];
            [fileContent writeToFile:[[outDirString stringByAppendingPathComponent:kNewClassDirName] stringByAppendingPathComponent:fileName] atomically:YES encoding:NSUTF8StringEncoding error:nil];
            
            printf("生成垃圾代码完成\n");
        }
    }
    return 0;
}

#pragma mark - 生成垃圾代码

void recursiveDirectory(NSString *directory, NSArray<NSString *> *ignoreDirNames, void(^handleMFile)(NSString *mFilePath), void(^handleSwiftFile)(NSString *swiftFilePath)) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath:directory error:nil];
    BOOL isDirectory;
    for (NSString *filePath in files) {
        NSString *path = [directory stringByAppendingPathComponent:filePath];
        if ([fm fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory) {
            if (![ignoreDirNames containsObject:filePath]) {
                recursiveDirectory(path, nil, handleMFile, handleSwiftFile);
            }
            continue;
        }
        NSString *fileName = filePath.lastPathComponent;
        if ([fileName hasSuffix:@".h"]) {
            fileName = [fileName stringByDeletingPathExtension];
            
            NSString *mFileName = [fileName stringByAppendingPathExtension:@"m"];
            if ([files containsObject:mFileName]) {
                handleMFile([directory stringByAppendingPathComponent:mFileName]);
            }
        } else if ([fileName hasSuffix:@".swift"]) {
            handleSwiftFile([directory stringByAppendingPathComponent:fileName]);
        }
    }
}

NSString * getImportString(NSString *hFileContent, NSString *mFileContent) {
    NSMutableString *ret = [NSMutableString string];
    
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"^ *[@#]import *.+" options:NSRegularExpressionAnchorsMatchLines|NSRegularExpressionUseUnicodeWordBoundaries error:nil];
    
    NSArray<NSTextCheckingResult *> *matches = [expression matchesInString:hFileContent options:0 range:NSMakeRange(0, hFileContent.length)];
    [matches enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *importRow = [hFileContent substringWithRange:[obj rangeAtIndex:0]];
        [ret appendString:importRow];
        [ret appendString:@"\n"];
    }];
    
    matches = [expression matchesInString:mFileContent options:0 range:NSMakeRange(0, mFileContent.length)];
    [matches enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *importRow = [mFileContent substringWithRange:[obj rangeAtIndex:0]];
        [ret appendString:importRow];
        [ret appendString:@"\n"];
    }];
    
    return ret;
}

static NSString *const kHClassFileTemplate = @"\
%@\n\
@interface %@ (%@)\n\
%@\n\
@end\n";
static NSString *const kMClassFileTemplate = @"\
#import \"%@+%@.h\"\n\
@implementation %@ (%@)\n\
%@\n\
@end\n";
static NSString *const kHNewClassFileTemplate = @"\
#import <Foundation/Foundation.h>\n\
@interface %@: NSObject\n\
%@\n\
@end\n";
static NSString *const kMNewClassFileTemplate = @"\
#import \"%@.h\"\n\
@implementation %@\n\
%@\n\
@end\n";
void generateSpamCodeFile(NSString *outDirectory, NSString *mFilePath, GSCSourceType type, NSMutableString *categoryCallImportString, NSMutableString *categoryCallFuncString, NSMutableString *newClassCallImportString, NSMutableString *newClassCallFuncString) {
    NSString *mFileContent = [NSString stringWithContentsOfFile:mFilePath encoding:NSUTF8StringEncoding error:nil];
    NSString *regexStr;
    switch (type) {
        case GSCSourceTypeClass:
            regexStr = @" *@implementation +(\\w+)[^(]*\\n(?:.|\\n)+?@end";
            break;
        case GSCSourceTypeCategory:
            regexStr = @" *@implementation *(\\w+) *\\((\\w+)\\)(?:.|\\n)+?@end";
            break;
    }
    
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:regexStr options:NSRegularExpressionUseUnicodeWordBoundaries error:nil];
    NSArray<NSTextCheckingResult *> *matches = [expression matchesInString:mFileContent options:0 range:NSMakeRange(0, mFileContent.length)];
    if (matches.count <= 0) return;
    
    NSString *hFilePath = [mFilePath.stringByDeletingPathExtension stringByAppendingPathExtension:@"h"];
    NSString *hFileContent = [NSString stringWithContentsOfFile:hFilePath encoding:NSUTF8StringEncoding error:nil];
    
    // 准备要引入的文件
    NSString *fileImportStrings = getImportString(hFileContent, mFileContent);
    
    [matches enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull impResult, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *className = [mFileContent substringWithRange:[impResult rangeAtIndex:1]];
        NSString *categoryName = nil;
        NSString *newClassName = [NSString stringWithFormat:@"%@%@%@", gOutParameterName, className, randomLetter()];
        if (impResult.numberOfRanges >= 3) {
            categoryName = [mFileContent substringWithRange:[impResult rangeAtIndex:2]];
        }
        
        if (type == GSCSourceTypeClass) {
            // 如果该类型没有公开，只在 .m 文件中使用，则不处理
            NSString *regexStr = [NSString stringWithFormat:@"\\b%@\\b", className];
            NSRange range = [hFileContent rangeOfString:regexStr options:NSRegularExpressionSearch];
            if (range.location == NSNotFound) {
                return;
            }
        }

        // 查找方法
        NSString *implementation = [mFileContent substringWithRange:impResult.range];
        NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"^ *([-+])[^)]+\\)([^;{]+)" options:NSRegularExpressionAnchorsMatchLines|NSRegularExpressionUseUnicodeWordBoundaries error:nil];
        NSArray<NSTextCheckingResult *> *matches = [expression matchesInString:implementation options:0 range:NSMakeRange(0, implementation.length)];
        if (matches.count <= 0) return;
        
        // 新类 h m 垃圾文件内容
        NSMutableString *hNewClassFileMethodsString = [NSMutableString string];
        NSMutableString *mNewClassFileMethodsString = [NSMutableString string];
        
        // 生成 h m 垃圾文件内容
        NSMutableString *hFileMethodsString = [NSMutableString string];
        NSMutableString *mFileMethodsString = [NSMutableString string];
        [matches enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull matche, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *symbol = @"+";//[implementation substringWithRange:[matche rangeAtIndex:1]];
            NSString *methodName = [[implementation substringWithRange:[matche rangeAtIndex:2]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSString *newClassMethodName = nil;
            NSString *methodCallName = nil;
            NSString *newClassMethodCallName = nil;
            if ([methodName containsString:@":"]) {
                // 去掉参数，生成无参数的新名称
                NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"\\b([\\w]+) *:" options:0 error:nil];
                NSArray<NSTextCheckingResult *> *matches = [expression matchesInString:methodName options:0 range:NSMakeRange(0, methodName.length)];
                if (matches.count > 0) {
                    NSMutableString *newMethodName = [NSMutableString string];
                    NSMutableString *newClassNewMethodName = [NSMutableString string];
                    [matches enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull matche, NSUInteger idx, BOOL * _Nonnull stop) {
                        NSString *str = [methodName substringWithRange:[matche rangeAtIndex:1]];
                        [newMethodName appendString:(newMethodName.length > 0 ? str.capitalizedString : str)];
                        [newClassNewMethodName appendFormat:@"%@%@", randomLetter(), str.capitalizedString];
                    }];
                    methodCallName = [NSString stringWithFormat:@"%@%@", newMethodName, gOutParameterName.capitalizedString];
                    [newMethodName appendFormat:@"%@:(NSInteger)%@", gOutParameterName.capitalizedString, gOutParameterName];
                    methodName = newMethodName;
                    
                    newClassMethodCallName = [NSString stringWithFormat:@"%@", newClassNewMethodName];
                    newClassMethodName = [NSString stringWithFormat:@"%@:(NSInteger)%@", newClassMethodCallName, gOutParameterName];
                } else {
                    methodName = [methodName stringByAppendingFormat:@" %@:(NSInteger)%@", gOutParameterName, gOutParameterName];
                }
            } else {
                newClassMethodCallName = [NSString stringWithFormat:@"%@%@", randomLetter(), methodName];
                newClassMethodName = [NSString stringWithFormat:@"%@:(NSInteger)%@", newClassMethodCallName, gOutParameterName];
                
                methodCallName = [NSString stringWithFormat:@"%@%@", methodName, gOutParameterName.capitalizedString];
                methodName = [methodName stringByAppendingFormat:@"%@:(NSInteger)%@", gOutParameterName.capitalizedString, gOutParameterName];
            }
            
            [hFileMethodsString appendFormat:@"%@ (BOOL)%@;\n", symbol, methodName];
            
            [mFileMethodsString appendFormat:@"%@ (BOOL)%@ {\n", symbol, methodName];
            [mFileMethodsString appendFormat:@"    return %@ %% %u == 0;\n", gOutParameterName, arc4random_uniform(50) + 1];
            [mFileMethodsString appendString:@"}\n"];
            
            if (methodCallName.length > 0) {
                if (gSpamCodeFuncationCallName && categoryCallFuncString.length <= 0) {
                    [categoryCallFuncString appendFormat:@"static inline NSInteger %@() {\nNSInteger ret = 0;\n", gSpamCodeFuncationCallName];
                }
                [categoryCallFuncString appendFormat:@"ret += [%@ %@:%u] ? 1 : 0;\n", className, methodCallName, arc4random_uniform(100)];
            }
            
            
            if (newClassMethodName.length > 0) {
                [hNewClassFileMethodsString appendFormat:@"%@ (BOOL)%@;\n", symbol, newClassMethodName];
                
                [mNewClassFileMethodsString appendFormat:@"%@ (BOOL)%@ {\n", symbol, newClassMethodName];
                [mNewClassFileMethodsString appendFormat:@"    return %@ %% %u == 0;\n", gOutParameterName, arc4random_uniform(50) + 1];
                [mNewClassFileMethodsString appendString:@"}\n"];
            }
            
            if (newClassMethodCallName.length > 0) {
                if (gNewClassFuncationCallName && newClassCallFuncString.length <= 0) {
                    [newClassCallFuncString appendFormat:@"static inline NSInteger %@() {\nNSInteger ret = 0;\n", gNewClassFuncationCallName];
                }
                [newClassCallFuncString appendFormat:@"ret += [%@ %@:%u] ? 1 : 0;\n", newClassName, newClassMethodCallName, arc4random_uniform(100)];
            }
        }];
        
        NSString *newCategoryName;
        switch (type) {
            case GSCSourceTypeClass:
                newCategoryName = gOutParameterName.capitalizedString;
                break;
            case GSCSourceTypeCategory:
                newCategoryName = [NSString stringWithFormat:@"%@%@", categoryName, gOutParameterName.capitalizedString];
                break;
        }
        
        // category m
        NSString *fileName = [NSString stringWithFormat:@"%@+%@.m", className, newCategoryName];
        NSString *fileContent = [NSString stringWithFormat:kMClassFileTemplate, className, newCategoryName, className, newCategoryName, mFileMethodsString];
        [fileContent writeToFile:[outDirectory stringByAppendingPathComponent:fileName] atomically:YES encoding:NSUTF8StringEncoding error:nil];
        // category h
        fileName = [NSString stringWithFormat:@"%@+%@.h", className, newCategoryName];
        fileContent = [NSString stringWithFormat:kHClassFileTemplate, fileImportStrings, className, newCategoryName, hFileMethodsString];
        [fileContent writeToFile:[outDirectory stringByAppendingPathComponent:fileName] atomically:YES encoding:NSUTF8StringEncoding error:nil];
        
        [categoryCallImportString appendFormat:@"#import \"%@\"\n", fileName];
        
        // new class m
        NSString *newOutDirectory = [outDirectory stringByAppendingPathComponent:kNewClassDirName];
        fileName = [NSString stringWithFormat:@"%@.m", newClassName];
        fileContent = [NSString stringWithFormat:kMNewClassFileTemplate, newClassName, newClassName, mNewClassFileMethodsString];
        [fileContent writeToFile:[newOutDirectory stringByAppendingPathComponent:fileName] atomically:YES encoding:NSUTF8StringEncoding error:nil];
        // new class h
        fileName = [NSString stringWithFormat:@"%@.h", newClassName];
        fileContent = [NSString stringWithFormat:kHNewClassFileTemplate, newClassName, hNewClassFileMethodsString];
        [fileContent writeToFile:[newOutDirectory stringByAppendingPathComponent:fileName] atomically:YES encoding:NSUTF8StringEncoding error:nil];
        
        [newClassCallImportString appendFormat:@"#import \"%@\"\n", fileName];
    }];
}

static NSString *const kSwiftFileTemplate = @"\
%@\n\
extension %@ {\n%@\
}\n";
static NSString *const kSwiftMethodTemplate = @"\
    func %@%@(_ %@: String%@) {\n\
        print(%@)\n\
    }\n";
void generateSwiftSpamCodeFile(NSString *outDirectory, NSString *swiftFilePath) {
    NSString *swiftFileContent = [NSString stringWithContentsOfFile:swiftFilePath encoding:NSUTF8StringEncoding error:nil];
    
    // 查找 class 声明
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@" *(class|struct) +(\\w+)[^{]+" options:NSRegularExpressionUseUnicodeWordBoundaries error:nil];
    NSArray<NSTextCheckingResult *> *matches = [expression matchesInString:swiftFileContent options:0 range:NSMakeRange(0, swiftFileContent.length)];
    if (matches.count <= 0) return;
    
    NSString *fileImportStrings = getSwiftImportString(swiftFileContent);
    __block NSInteger braceEndIndex = 0;
    [matches enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull classResult, NSUInteger idx, BOOL * _Nonnull stop) {
        // 已经处理到该 range 后面去了，过掉
        NSInteger matchEndIndex = classResult.range.location + classResult.range.length;
        if (matchEndIndex < braceEndIndex) return;
        // 是 class 方法，过掉
        NSString *fullMatchString = [swiftFileContent substringWithRange:classResult.range];
        if ([fullMatchString containsString:@"("]) return;
        
        NSRange braceRange = getOutermostCurlyBraceRange(swiftFileContent, '{', '}', matchEndIndex);
        braceEndIndex = braceRange.location + braceRange.length;
        
        // 查找方法
        NSString *classContent = [swiftFileContent substringWithRange:braceRange];
        NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"func +([^(]+)\\([^{]+" options:NSRegularExpressionUseUnicodeWordBoundaries error:nil];
        NSArray<NSTextCheckingResult *> *matches = [expression matchesInString:classContent options:0 range:NSMakeRange(0, classContent.length)];
        if (matches.count <= 0) return;
        
        NSMutableString *methodsString = [NSMutableString string];
        [matches enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull funcResult, NSUInteger idx, BOOL * _Nonnull stop) {
            NSRange funcNameRange = [funcResult rangeAtIndex:1];
            NSString *funcName = [classContent substringWithRange:funcNameRange];
            NSRange oldParameterRange = getOutermostCurlyBraceRange(classContent, '(', ')', funcNameRange.location + funcNameRange.length);
            NSString *oldParameterName = [classContent substringWithRange:oldParameterRange];
            oldParameterName = [oldParameterName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (oldParameterName.length > 0) {
                oldParameterName = [@", " stringByAppendingString:oldParameterName];
            }
            if (![funcName containsString:@"<"] && ![funcName containsString:@">"]) {
                funcName = [NSString stringWithFormat:@"%@%@", funcName, randomString(5)];
                [methodsString appendFormat:kSwiftMethodTemplate, funcName, gOutParameterName.capitalizedString, gOutParameterName, oldParameterName, gOutParameterName];
            } else {
                NSLog(@"string contains `[` or `]` bla! funcName: %@", funcName);
            }
        }];
        if (methodsString.length <= 0) return;
        
        NSString *className = [swiftFileContent substringWithRange:[classResult rangeAtIndex:2]];
        
        NSString *fileName = [NSString stringWithFormat:@"%@%@Ext.swift", className, gOutParameterName.capitalizedString];
        NSString *filePath = [outDirectory stringByAppendingPathComponent:fileName];
        NSString *fileContent = @"";
        if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
            fileContent = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
        }
        fileContent = [fileContent stringByAppendingFormat:kSwiftFileTemplate, fileImportStrings, className, methodsString];
        [fileContent writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }];
}

#pragma mark - 处理 Xcassets 中的图片文件

void handleXcassetsFiles(NSString *directory) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath:directory error:nil];
    BOOL isDirectory;
    for (NSString *fileName in files) {
        NSString *filePath = [directory stringByAppendingPathComponent:fileName];
        if ([fm fileExistsAtPath:filePath isDirectory:&isDirectory] && isDirectory) {
            handleXcassetsFiles(filePath);
            continue;
        }
        if (![fileName isEqualToString:@"Contents.json"]) continue;
        NSString *contentsDirectoryName = filePath.stringByDeletingLastPathComponent.lastPathComponent;
        if (![contentsDirectoryName hasSuffix:@".imageset"]) continue;
        
        NSString *fileContent = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
        if (!fileContent) continue;
        
        NSMutableArray<NSString *> *processedImageFileNameArray = @[].mutableCopy;
        static NSString * const regexStr = @"\"filename\" *: *\"(.*)?\"";
        NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:regexStr options:NSRegularExpressionUseUnicodeWordBoundaries error:nil];
        NSArray<NSTextCheckingResult *> *matches = [expression matchesInString:fileContent options:0 range:NSMakeRange(0, fileContent.length)];
        while (matches.count > 0) {
            NSInteger i = 0;
            NSString *imageFileName = nil;
            do {
                if (i >= matches.count) {
                    i = -1;
                    break;
                }
                imageFileName = [fileContent substringWithRange:[matches[i] rangeAtIndex:1]];
                i++;
            } while ([processedImageFileNameArray containsObject:imageFileName]);
            if (i < 0) break;
            
            NSString *imageFilePath = [filePath.stringByDeletingLastPathComponent stringByAppendingPathComponent:imageFileName];
            if ([fm fileExistsAtPath:imageFilePath]) {
                NSString *newImageFileName = [randomString(10) stringByAppendingPathExtension:imageFileName.pathExtension];
                NSString *newImageFilePath = [filePath.stringByDeletingLastPathComponent stringByAppendingPathComponent:newImageFileName];
                while ([fm fileExistsAtPath:newImageFileName]) {
                    newImageFileName = [randomString(10) stringByAppendingPathExtension:imageFileName.pathExtension];
                    newImageFilePath = [filePath.stringByDeletingLastPathComponent stringByAppendingPathComponent:newImageFileName];
                }
                
                renameFile(imageFilePath, newImageFilePath);
                
                fileContent = [fileContent stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"\"%@\"", imageFileName]
                                                                     withString:[NSString stringWithFormat:@"\"%@\"", newImageFileName]];
                [fileContent writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
                
                [processedImageFileNameArray addObject:newImageFileName];
            } else {
                [processedImageFileNameArray addObject:imageFileName];
            }
            
            matches = [expression matchesInString:fileContent options:0 range:NSMakeRange(0, fileContent.length)];
        }
    }
}

#pragma mark - 删除注释

void deleteComments(NSString *directory, NSArray<NSString *> *ignoreDirNames) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath:directory error:nil];
    BOOL isDirectory;
    for (NSString *fileName in files) {
        if ([ignoreDirNames containsObject:fileName]) continue;
        NSString *filePath = [directory stringByAppendingPathComponent:fileName];
        if ([fm fileExistsAtPath:filePath isDirectory:&isDirectory] && isDirectory) {
            deleteComments(filePath, ignoreDirNames);
            continue;
        }
        if (![fileName hasSuffix:@".h"] && ![fileName hasSuffix:@".m"] && ![fileName hasSuffix:@".mm"] && ![fileName hasSuffix:@".swift"]) continue;
        NSMutableString *fileContent = [NSMutableString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
        regularReplacement(fileContent, @"([^:/])//.*",             @"\\1");
        regularReplacement(fileContent, @"^//.*",                   @"");
        regularReplacement(fileContent, @"/\\*{1,2}[\\s\\S]*?\\*/", @"");
        regularReplacement(fileContent, @"^\\s*\\n",                @"");
        [fileContent writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

#pragma mark - 修改工程名

void resetEntitlementsFileName(NSString *projectPbxprojFilePath, NSString *oldName, NSString *newName) {
    NSString *rootPath = projectPbxprojFilePath.stringByDeletingLastPathComponent.stringByDeletingLastPathComponent;
    NSMutableString *fileContent = [NSMutableString stringWithContentsOfFile:projectPbxprojFilePath encoding:NSUTF8StringEncoding error:nil];
    
    NSString *regularExpression = @"CODE_SIGN_ENTITLEMENTS = \"?([^\";]+)";
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:regularExpression options:0 error:nil];
    NSArray<NSTextCheckingResult *> *matches = [expression matchesInString:fileContent options:0 range:NSMakeRange(0, fileContent.length)];
    [matches enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSTextCheckingResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *entitlementsPath = [fileContent substringWithRange:[obj rangeAtIndex:1]];
        NSString *entitlementsName = entitlementsPath.lastPathComponent.stringByDeletingPathExtension;
        if (![entitlementsName isEqualToString:oldName]) return;
        entitlementsPath = [rootPath stringByAppendingPathComponent:entitlementsPath];
        if (![[NSFileManager defaultManager] fileExistsAtPath:entitlementsPath]) return;
        NSString *newPath = [entitlementsPath.stringByDeletingLastPathComponent stringByAppendingPathComponent:[newName stringByAppendingPathExtension:@"entitlements"]];
        renameFile(entitlementsPath, newPath);
    }];
}

void resetBridgingHeaderFileName(NSString *projectPbxprojFilePath, NSString *oldName, NSString *newName) {
    NSString *rootPath = projectPbxprojFilePath.stringByDeletingLastPathComponent.stringByDeletingLastPathComponent;
    NSMutableString *fileContent = [NSMutableString stringWithContentsOfFile:projectPbxprojFilePath encoding:NSUTF8StringEncoding error:nil];
    
    NSString *regularExpression = @"SWIFT_OBJC_BRIDGING_HEADER = \"?([^\";]+)";
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:regularExpression options:0 error:nil];
    NSArray<NSTextCheckingResult *> *matches = [expression matchesInString:fileContent options:0 range:NSMakeRange(0, fileContent.length)];
    [matches enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSTextCheckingResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *entitlementsPath = [fileContent substringWithRange:[obj rangeAtIndex:1]];
        NSString *entitlementsName = entitlementsPath.lastPathComponent.stringByDeletingPathExtension;
        if (![entitlementsName isEqualToString:oldName]) return;
        entitlementsPath = [rootPath stringByAppendingPathComponent:entitlementsPath];
        if (![[NSFileManager defaultManager] fileExistsAtPath:entitlementsPath]) return;
        NSString *newPath = [entitlementsPath.stringByDeletingLastPathComponent stringByAppendingPathComponent:[newName stringByAppendingPathExtension:@"h"]];
        renameFile(entitlementsPath, newPath);
    }];
}

void replacePodfileContent(NSString *filePath, NSString *oldString, NSString *newString) {
    NSMutableString *fileContent = [NSMutableString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    
    NSString *regularExpression = [NSString stringWithFormat:@"target +'%@", oldString];
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:regularExpression options:0 error:nil];
    NSArray<NSTextCheckingResult *> *matches = [expression matchesInString:fileContent options:0 range:NSMakeRange(0, fileContent.length)];
    [matches enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSTextCheckingResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [fileContent replaceCharactersInRange:obj.range withString:[NSString stringWithFormat:@"target '%@", newString]];
    }];
    
    regularExpression = [NSString stringWithFormat:@"project +'%@.", oldString];
    expression = [NSRegularExpression regularExpressionWithPattern:regularExpression options:0 error:nil];
    matches = [expression matchesInString:fileContent options:0 range:NSMakeRange(0, fileContent.length)];
    [matches enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSTextCheckingResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [fileContent replaceCharactersInRange:obj.range withString:[NSString stringWithFormat:@"project '%@.", newString]];
    }];
    
    [fileContent writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

void replaceProjectFileContent(NSString *filePath, NSString *oldString, NSString *newString) {
    NSMutableString *fileContent = [NSMutableString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    
    NSString *regularExpression = [NSString stringWithFormat:@"\\b%@\\b", oldString];
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:regularExpression options:0 error:nil];
    NSArray<NSTextCheckingResult *> *matches = [expression matchesInString:fileContent options:0 range:NSMakeRange(0, fileContent.length)];
    [matches enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSTextCheckingResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [fileContent replaceCharactersInRange:obj.range withString:newString];
    }];
    
    [fileContent writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

void modifyFilesClassName(NSString *sourceCodeDir, NSString *oldClassName, NSString *newClassName);

void modifyProjectName(NSString *projectDir, NSString *oldName, NSString *newName) {
    NSString *sourceCodeDirPath = [projectDir stringByAppendingPathComponent:oldName];
    NSString *xcodeprojFilePath = [sourceCodeDirPath stringByAppendingPathExtension:@"xcodeproj"];
    NSString *xcworkspaceFilePath = [sourceCodeDirPath stringByAppendingPathExtension:@"xcworkspace"];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDirectory;
    
    // old-Swift.h > new-Swift.h
    modifyFilesClassName(projectDir, [oldName stringByAppendingString:@"-Swift.h"], [newName stringByAppendingString:@"-Swift.h"]);
    
    // 改 Podfile 中的工程名
    NSString *podfilePath = [projectDir stringByAppendingPathComponent:@"Podfile"];
    if ([fm fileExistsAtPath:podfilePath isDirectory:&isDirectory] && !isDirectory) {
        replacePodfileContent(podfilePath, oldName, newName);
    }
    
    // 改工程文件内容
    if ([fm fileExistsAtPath:xcodeprojFilePath isDirectory:&isDirectory] && isDirectory) {
        // 替换 project.pbxproj 文件内容
        NSString *projectPbxprojFilePath = [xcodeprojFilePath stringByAppendingPathComponent:@"project.pbxproj"];
        if ([fm fileExistsAtPath:projectPbxprojFilePath]) {
            resetBridgingHeaderFileName(projectPbxprojFilePath, [oldName stringByAppendingString:@"-Bridging-Header"], [newName stringByAppendingString:@"-Bridging-Header"]);
            resetEntitlementsFileName(projectPbxprojFilePath, oldName, newName);
            replaceProjectFileContent(projectPbxprojFilePath, oldName, newName);
        }
        // 替换 project.xcworkspace/contents.xcworkspacedata 文件内容
        NSString *contentsXcworkspacedataFilePath = [xcodeprojFilePath stringByAppendingPathComponent:@"project.xcworkspace/contents.xcworkspacedata"];
        if ([fm fileExistsAtPath:contentsXcworkspacedataFilePath]) {
            replaceProjectFileContent(contentsXcworkspacedataFilePath, oldName, newName);
        }
        // xcuserdata 本地用户文件
        NSString *xcuserdataFilePath = [xcodeprojFilePath stringByAppendingPathComponent:@"xcuserdata"];
        if ([fm fileExistsAtPath:xcuserdataFilePath]) {
            [fm removeItemAtPath:xcuserdataFilePath error:nil];
        }
        // 改名工程文件
        renameFile(xcodeprojFilePath, [[projectDir stringByAppendingPathComponent:newName] stringByAppendingPathExtension:@"xcodeproj"]);
    }
    
    // 改工程组文件内容
    if ([fm fileExistsAtPath:xcworkspaceFilePath isDirectory:&isDirectory] && isDirectory) {
        // 替换 contents.xcworkspacedata 文件内容
        NSString *contentsXcworkspacedataFilePath = [xcworkspaceFilePath stringByAppendingPathComponent:@"contents.xcworkspacedata"];
        if ([fm fileExistsAtPath:contentsXcworkspacedataFilePath]) {
            replaceProjectFileContent(contentsXcworkspacedataFilePath, oldName, newName);
        }
        // xcuserdata 本地用户文件
        NSString *xcuserdataFilePath = [xcworkspaceFilePath stringByAppendingPathComponent:@"xcuserdata"];
        if ([fm fileExistsAtPath:xcuserdataFilePath]) {
            [fm removeItemAtPath:xcuserdataFilePath error:nil];
        }
        // 改名工程文件
        renameFile(xcworkspaceFilePath, [[projectDir stringByAppendingPathComponent:newName] stringByAppendingPathExtension:@"xcworkspace"]);
    }
    
    // 改源代码文件夹名称
    if ([fm fileExistsAtPath:sourceCodeDirPath isDirectory:&isDirectory] && isDirectory) {
        renameFile(sourceCodeDirPath, [projectDir stringByAppendingPathComponent:newName]);
    }
}

#pragma mark - 修改类名前缀

void modifyFilesClassName(NSString *sourceCodeDir, NSString *oldClassName, NSString *newClassName) {
    // 文件内容 Const > DDConst (h,m,swift,xib,storyboard)
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath:sourceCodeDir error:nil];
    BOOL isDirectory;
    for (NSString *filePath in files) {
        NSString *path = [sourceCodeDir stringByAppendingPathComponent:filePath];
        if ([fm fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory) {
            modifyFilesClassName(path, oldClassName, newClassName);
            continue;
        }
        
        NSString *fileName = filePath.lastPathComponent;
        if ([fileName hasSuffix:@".h"] || [fileName hasSuffix:@".m"] || [fileName hasSuffix:@".pch"] || [fileName hasSuffix:@".swift"] || [fileName hasSuffix:@".xib"] || [fileName hasSuffix:@".storyboard"]) {
            
            NSError *error = nil;
            NSMutableString *fileContent = [NSMutableString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
            if (error) {
                printf("打开文件 %s 失败：%s\n", path.UTF8String, error.localizedDescription.UTF8String);
                abort();
            }
            
            NSString *regularExpression = [NSString stringWithFormat:@"\\b%@\\b", oldClassName];
            BOOL isChanged = regularReplacement(fileContent, regularExpression, newClassName);
            if (!isChanged) continue;
            error = nil;
            [fileContent writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
            if (error) {
                printf("保存文件 %s 失败：%s\n", path.UTF8String, error.localizedDescription.UTF8String);
                abort();
            }
        }
    }
}

void modifyClassNamePrefix(NSMutableString *projectContent, NSString *sourceCodeDir, NSArray<NSString *> *ignoreDirNames, NSString *oldName, NSString *newName) {
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // 遍历源代码文件 h 与 m 配对，swift
    NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath:sourceCodeDir error:nil];
    BOOL isDirectory;
    for (NSString *filePath in files) {
        NSString *path = [sourceCodeDir stringByAppendingPathComponent:filePath];
        if ([fm fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory) {
            if (![ignoreDirNames containsObject:filePath]) {
                modifyClassNamePrefix(projectContent, path, ignoreDirNames, oldName, newName);
            }
            continue;
        }
        
        NSString *fileName = filePath.lastPathComponent.stringByDeletingPathExtension;
        NSString *fileExtension = filePath.pathExtension;
        NSString *newClassName;
        if ([fileName hasPrefix:oldName]) {
            newClassName = [newName stringByAppendingString:[fileName substringFromIndex:oldName.length]];
        } else {
            //处理是category的情况。当是category时，修改+号后面的类名前缀
            NSString *oldNamePlus = [NSString stringWithFormat:@"+%@",oldName];
            if ([fileName containsString:oldNamePlus]) {
                NSMutableString *fileNameStr = [[NSMutableString alloc] initWithString:fileName];
                [fileNameStr replaceCharactersInRange:[fileName rangeOfString:oldNamePlus] withString:[NSString stringWithFormat:@"+%@",newName]];
                newClassName = fileNameStr;
            }else{
                newClassName = [newName stringByAppendingString:fileName];
            }
        }
        
        // 文件名 Const.ext > DDConst.ext
        if ([fileExtension isEqualToString:@"h"]) {
            NSString *mFileName = [fileName stringByAppendingPathExtension:@"m"];
            if ([files containsObject:mFileName]) {
                NSString *oldFilePath = [[sourceCodeDir stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:@"h"];
                NSString *newFilePath = [[sourceCodeDir stringByAppendingPathComponent:newClassName] stringByAppendingPathExtension:@"h"];
                renameFile(oldFilePath, newFilePath);
                oldFilePath = [[sourceCodeDir stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:@"m"];
                newFilePath = [[sourceCodeDir stringByAppendingPathComponent:newClassName] stringByAppendingPathExtension:@"m"];
                renameFile(oldFilePath, newFilePath);
                oldFilePath = [[sourceCodeDir stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:@"xib"];
                if ([fm fileExistsAtPath:oldFilePath]) {
                    newFilePath = [[sourceCodeDir stringByAppendingPathComponent:newClassName] stringByAppendingPathExtension:@"xib"];
                    renameFile(oldFilePath, newFilePath);
                }
                
                @autoreleasepool {
                    modifyFilesClassName(gSourceCodeDir, fileName, newClassName);
                }
            } else {
                continue;
            }
        } else if ([fileExtension isEqualToString:@"swift"]) {
            NSString *oldFilePath = [[sourceCodeDir stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:@"swift"];
            NSString *newFilePath = [[sourceCodeDir stringByAppendingPathComponent:newClassName] stringByAppendingPathExtension:@"swift"];
            renameFile(oldFilePath, newFilePath);
            oldFilePath = [[sourceCodeDir stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:@"xib"];
            if ([fm fileExistsAtPath:oldFilePath]) {
                newFilePath = [[sourceCodeDir stringByAppendingPathComponent:newClassName] stringByAppendingPathExtension:@"xib"];
                renameFile(oldFilePath, newFilePath);
            }
            
            @autoreleasepool {
                modifyFilesClassName(gSourceCodeDir, fileName.stringByDeletingPathExtension, newClassName);
            }
        } else {
            continue;
        }
        
        // 修改工程文件中的文件名
        NSString *regularExpression = [NSString stringWithFormat:@"\\b%@\\b", fileName];
        regularReplacement(projectContent, regularExpression, newClassName);
    }
}

#pragma mark  =========== 添加垃圾API ==========
///添加垃圾代码的策略
///为每一个.m文件添加一个方法，
void addSpamCodeFile(NSString *sourceCodeDir, NSArray<NSString *> *ignoreDirNames){
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath:sourceCodeDir error:nil];
    BOOL isDirectory;
    
    for (NSString *filePath in files) {
        if ([ignoreDirNames containsObject:filePath]) continue;
        NSString *path = [sourceCodeDir stringByAppendingPathComponent:filePath];
        ///如果路径下的是文件夹，继续往下走,知道找到一个文件
        
        if ([fm fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory) {
            addSpamCodeFile(path, ignoreDirNames);
            continue;
        }
        NSString *fileName = filePath.lastPathComponent;
        ///mm文件先不管
        if ([fileName hasSuffix:@".h"]) {
            NSString *hfileName = fileName.stringByDeletingPathExtension;
            NSString *mFileName = [hfileName stringByAppendingPathExtension:@"m"];
            if (![files containsObject:mFileName]) {
                continue;
            }
            
            NSArray *apiList = @[@"sc_checkUserInfo",@"sc_upload",@"sc_getMediaData",@"sc_didGetInfoSuccess",@"sc_getUserFollowSuccess",@"sc_getLoginState",@"sc_checkNetWorking",@"sc_checkInfo",@"sc_getMediaFailed",@"sc_getUserName",@"sc_checkDefualtSetting",@"sc_didUserInfoFailed",@"sc_getUsersMostLiked",@"sc_getUsersMostLikedSuccess",@"sc_getUsersMostFollowerSuccess"];
            NSArray *logList = @[@"Get Info Success",@"Get Info Failed",@"Continue",@"Check your Network",@"Get User Succrss"];
            NSArray *param = @[@"string",@"mediaInfo",@"followCount",@"mediaCount",@"isLogin"];
            int listIndex = arc4random() % 15;
            int logIndex = arc4random() % 5;
            
            creatApiToFile(sourceCodeDir, apiList[listIndex], param[logIndex], logList[logIndex], [sourceCodeDir stringByAppendingPathComponent:filePath], YES);
            
            creatApiToFile(sourceCodeDir, apiList[listIndex], param[logIndex], logList[logIndex], filePath, NO);
            kSpamCount += 1;
            
        }
    }
}

void creatApiToFile(NSString *sourceCodeDir,NSString *apiName, NSString *paramName,NSString *logName,NSString *filePath, BOOL isHfile){
    if(isHfile){
        NSError *error = nil;
        NSMutableString *fileContent = [NSMutableString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
        if([fileContent containsString:[NSString stringWithFormat:@"- (void)%@:(NSString *)%@;\n", apiName,paramName]]){
            return;
        }
        if(kSpamCount%4 == 0){
            NSString *s = @"@end";
            NSArray *endArray = [fileContent componentsSeparatedByString:s];
            NSMutableArray *arrayOfLocation=[NSMutableArray new];
            int d=0;
            for (int i=0; i<endArray.count-1; i++) {
                
                NSString *string=endArray[i];
                NSNumber *number=[NSNumber numberWithInt:d+=string.length];
                
                d+=s.length;
                [arrayOfLocation addObject:number];
                
            }
            NSNumber *number = arrayOfLocation[arrayOfLocation.count-1];
            NSInteger index = number.integerValue;
            [fileContent replaceCharactersInRange:NSMakeRange(index, 4) withString:@""];
            [fileContent appendFormat:@"- (void)%@:(NSString *)%@;\n", apiName,paramName];
            [fileContent appendString:@"@end\n"];
        }
        else{
            NSString *s = @"@end";
            NSArray *endArray = [fileContent componentsSeparatedByString:s];
            NSMutableArray *arrayOfLocation=[NSMutableArray new];
            int d=0;
            for (int i=0; i<endArray.count-1; i++) {
                
                NSString *string=endArray[i];
                NSNumber *number=[NSNumber numberWithInt:d+=string.length];
                
                d+=s.length;
                [arrayOfLocation addObject:number];
                
            }
            NSNumber *number = arrayOfLocation[arrayOfLocation.count-1];
            NSInteger index = number.integerValue;
            [fileContent replaceCharactersInRange:NSMakeRange(index, 4) withString:@""];
            [fileContent appendFormat:@"- (void)%@;\n", apiName];
            [fileContent appendString:@"@end\n"];
        }
        [fileContent writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    else{
        NSString *sfileName = filePath.lastPathComponent.stringByDeletingPathExtension;
        NSString *mFileName = [sfileName stringByAppendingPathExtension:@"m"];
        NSString *mfilePath = [sourceCodeDir stringByAppendingPathComponent:mFileName];
        NSError *merror = nil;
        NSMutableString *mfileContent = [NSMutableString stringWithContentsOfFile:mfilePath encoding:NSUTF8StringEncoding error:&merror];
        if([mfileContent containsString:[NSString stringWithFormat:@"- (void)%@:(NSString *)%@ {\n", apiName, paramName]]){
            return;
        }
        if(kSpamCount%4 == 0){
            NSString *s = @"@end";
            NSArray *endArray = [mfileContent componentsSeparatedByString:s];
            NSMutableArray *arrayOfLocation=[NSMutableArray new];
            int d=0;
            for (int i=0; i<endArray.count-1; i++) {
                
                NSString *string=endArray[i];
                NSNumber *number=[NSNumber numberWithInt:d+=string.length];
                
                d+=s.length;
                [arrayOfLocation addObject:number];
                
            }
            NSNumber *number = arrayOfLocation[arrayOfLocation.count-1];
            NSInteger index = number.integerValue;
            [mfileContent replaceCharactersInRange:NSMakeRange(index, 4) withString:@""];
            [mfileContent appendFormat:@"- (void)%@:(NSString *)%@ {\n", apiName, paramName];
            [mfileContent appendFormat:@"    NSLog(@\"%@\");\n", logName];
            [mfileContent appendString:@"}\n"];
            [mfileContent appendString:@"@end\n"];
            
        }
        else{
            NSString *s = @"@end";
            NSArray *endArray = [mfileContent componentsSeparatedByString:s];
            NSMutableArray *arrayOfLocation=[NSMutableArray new];
            int d=0;
            for (int i=0; i<endArray.count-1; i++) {
                
                NSString *string=endArray[i];
                NSNumber *number=[NSNumber numberWithInt:d+=string.length];
                
                d+=s.length;
                [arrayOfLocation addObject:number];
                
            }
            NSNumber *number = arrayOfLocation[arrayOfLocation.count-1];
            NSInteger index = number.integerValue;
            [mfileContent replaceCharactersInRange:NSMakeRange(index, 4) withString:@""];
            [mfileContent appendFormat:@"- (void)%@ {\n", apiName];
            [mfileContent appendFormat:@"    NSLog(@\"%@\");\n", logName];
            [mfileContent appendString:@"}\n"];
            [mfileContent appendString:@"@end\n"];
        }
        [mfileContent writeToFile:[sourceCodeDir stringByAppendingPathComponent:mFileName] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

#pragma mark  =========== 修改 API 名称 ==========
void changeAPIName(NSString *sourceCodeDir,NSString *oldName){
    NSString *path1 = modifyApiNameList.mutableCopy;
    NSString *path2 = modifyApiNewAPIList.mutableCopy;
    NSDictionary *dic = [NSDictionary dictionaryWithContentsOfFile:path1];
    NSMutableArray *newArr = [NSMutableArray arrayWithContentsOfFile:path2];
    NSArray *arr1 = dic[@"firstArray"];
    NSArray *arr2 = dic[@"secondArray"];
    NSArray *arr3 = dic[@"thirdArray"];
    NSArray *arr4 = dic[@"forthArray"];
    NSArray *arr5 = dic[@"fifthArray"];
    NSArray *arr6 = dic[@"sixthArray"];
    NSString *newName;
    while (1) {
        NSInteger k1 = arc4random()%8;
        NSInteger k2 = arc4random()%8;
        NSInteger k3 = arc4random()%8;
        NSInteger k4 = arc4random()%8;
        NSInteger k5 = arc4random()%8;
        NSInteger k6 = arc4random()%8;
        newName = [NSString stringWithFormat:@"newApi_%@%@%@%@%@%@",arr1[k1],arr2[k2],arr3[k3],arr4[k4],arr5[k5],arr6[k6]];
        if(![newArr containsObject:newName]){
            break;
        }
    }
    [newArr addObject:newName];
    [newArr writeToFile:path2 atomically:YES];
    @autoreleasepool {
        printf("修改API名:\n旧API:%s\n新API:%s\n", oldName.UTF8String, newName.UTF8String);
        modifyApi(gSourceCodeDir, oldName, newName);
    }
}

void modifyApi(NSString *sourceCodeDir,NSString *oldName,NSString *newName){
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // 遍历源代码文件 h 与 m 配对
    NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath:sourceCodeDir error:nil];
    BOOL isDirectory;
    for (NSString *filePath in files) {
        NSString *path = [sourceCodeDir stringByAppendingPathComponent:filePath];
        if ([fm fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory) {
            modifyApi(path, oldName, newName);
            continue;
        }
        ///如果
        NSString *fileName = filePath.lastPathComponent.stringByDeletingPathExtension;
        NSString *fileExtension = filePath.pathExtension;
        if ([fileExtension isEqualToString:@"h"]) {
            NSString *mFileName = [fileName stringByAppendingPathExtension:@"m"];
            NSString *mmFileName = [fileName stringByAppendingPathExtension:@"mm"];
            NSString *hFilePath = [[sourceCodeDir stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:@"h"];
            NSMutableString *hfileConten = [NSMutableString stringWithContentsOfFile:hFilePath encoding:NSUTF8StringEncoding error:nil];
            if ([files containsObject:mFileName]){
                NSString *hFilePath = [[sourceCodeDir stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:@"h"];
                NSString *mFilePath = [[sourceCodeDir stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:@"m"];
                NSError *error = nil;
                NSMutableString *fileContent = [NSMutableString stringWithContentsOfFile:mFilePath encoding:NSUTF8StringEncoding error:&error];
                if([fileContent containsString:oldName]){
                    [fileContent replaceOccurrencesOfString:oldName withString:newName options:NSCaseInsensitiveSearch range:NSMakeRange(0, fileContent.length)];
                    [fileContent writeToFile:mFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
                }
                NSMutableString *hfileConten = [NSMutableString stringWithContentsOfFile:hFilePath encoding:NSUTF8StringEncoding error:nil];
                if([hfileConten containsString:oldName]){
                    [hfileConten replaceOccurrencesOfString:oldName withString:newName options:NSCaseInsensitiveSearch range:NSMakeRange(0, hfileConten.length)];
                    [hfileConten writeToFile:hFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
                }
            }
            
            else if ([files containsObject:mmFileName]){
                NSString *hFilePath = [[sourceCodeDir stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:@"h"];
                NSString *mFilePath = [[sourceCodeDir stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:@"mm"];
                NSError *error = nil;
                NSMutableString *fileContent = [NSMutableString stringWithContentsOfFile:mFilePath encoding:NSUTF8StringEncoding error:&error];
                if([fileContent containsString:oldName]){
                    [fileContent replaceOccurrencesOfString:oldName withString:newName options:NSCaseInsensitiveSearch range:NSMakeRange(0, fileContent.length)];
                    [fileContent writeToFile:mFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
                }
                NSMutableString *hfileConten = [NSMutableString stringWithContentsOfFile:hFilePath encoding:NSUTF8StringEncoding error:nil];
                if([hfileConten containsString:oldName]){
                    [hfileConten replaceOccurrencesOfString:oldName withString:newName options:NSCaseInsensitiveSearch range:NSMakeRange(0, hfileConten.length)];
                    [hfileConten writeToFile:hFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
                }
            }
            else{
                if([hfileConten containsString:oldName]){
                    [hfileConten replaceOccurrencesOfString:oldName withString:newName options:NSCaseInsensitiveSearch range:NSMakeRange(0, hfileConten.length)];
                    [hfileConten writeToFile:hFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
                }
            }
        }
    }
}
