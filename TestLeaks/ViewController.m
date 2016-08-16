//
//  ViewController.m
//  TestLeaks
//
//  Created by 常彪 on 16/8/16.
//  Copyright © 2016年 0xcb. All rights reserved.
//

#import "ViewController.h"
#import <libxml2/libxml/tree.h>
#import <libxml/HTMLparser.h>
#import <TFHpple.h>


static inline NSDictionary *DictionaryForNode(xmlNodePtr currentNode, NSMutableDictionary *parentResult,BOOL parentContent)
{
    @autoreleasepool {
        //NSMutableDictionary *resultForNode = [@{} mutableCopy];
        NSMutableDictionary *resultForNode = [NSMutableDictionary dictionary];
        if (currentNode->name) {
            NSString *currentNodeContent = [NSString stringWithCString:(const char *)currentNode->name
                                                              encoding:NSUTF8StringEncoding];
            resultForNode[@"nodeName"] = currentNodeContent;
            //0xcb
            currentNodeContent = nil;
        }
        
        xmlChar *nodeContent = xmlNodeGetContent(currentNode);
        if (nodeContent != NULL) {
            NSString *currentNodeContent = [NSString stringWithCString:(const char *)nodeContent
                                                              encoding:NSUTF8StringEncoding];
            if ([resultForNode[@"nodeName"] isEqual:@"text"] && parentResult) {
                if (parentContent) {
                    NSCharacterSet *charactersToTrim = [NSCharacterSet whitespaceAndNewlineCharacterSet];
                    parentResult[@"nodeContent"] = [currentNodeContent stringByTrimmingCharactersInSet:charactersToTrim];
                    //0xcb
                    currentNodeContent = nil;
                    charactersToTrim = nil;
                    
                    xmlFree(nodeContent);
                    return nil;
                }
                if (currentNodeContent != nil) {
                    resultForNode[@"nodeContent"] = currentNodeContent;
                }
                //0xcb
                currentNodeContent = nil;
                xmlFree(nodeContent);
                return resultForNode;
            } else {
                resultForNode[@"nodeContent"] = currentNodeContent;
            }
            //0xcb
            currentNodeContent = nil;
            xmlFree(nodeContent);
        }
        
        xmlAttr *attribute = currentNode->properties;
        if (attribute) {
            //NSMutableArray *attributeArray = [@[] mutableCopy];
            NSMutableArray *attributeArray = [NSMutableArray array];
            while (attribute) {
                @autoreleasepool
                {
                    //NSMutableDictionary *attributeDictionary = [@{} mutableCopy];
                    NSMutableDictionary *attributeDictionary = [NSMutableDictionary dictionary];
                    NSString *attributeName = [NSString stringWithCString:(const char *)attribute->name
                                                                 encoding:NSUTF8StringEncoding];
                    if (attributeName) {
                        attributeDictionary[@"attributeName"] = attributeName;
                    }
                    //0xcb
                    attributeName = nil;
                    
                    if (attribute->children) {
                        NSDictionary *childDictionary = DictionaryForNode(attribute->children, attributeDictionary, true);
                        if (childDictionary) {
                            attributeDictionary[@"attributeContent"] = childDictionary;
                        }
                        //0xcb
                        childDictionary = nil;
                    }
                    
                    if ([attributeDictionary count] > 0) {
                        [attributeArray addObject:attributeDictionary];
                    }
                    attribute = attribute->next;
                    attributeDictionary = nil;
                }
            }
            
            if ([attributeArray count] > 0) {
                resultForNode[@"nodeAttributeArray"] = attributeArray;
            }
            attributeArray = nil;
        }
        
        xmlNodePtr childNode = currentNode->children;
        if (childNode) {
            //NSMutableArray *childContentArray = [@[] mutableCopy];
            NSMutableArray *childContentArray = [NSMutableArray array];
            while (childNode) {
                NSDictionary *childDictionary = DictionaryForNode(childNode, resultForNode,false);
                if (childDictionary) {
                    [childContentArray addObject:childDictionary];
                }
                //0xcb
                childDictionary = nil;
                childNode = childNode->next;
            }
            if ([childContentArray count] > 0) {
                resultForNode[@"nodeChildArray"] = childContentArray;
            }
            childContentArray = nil;
        }
        
        xmlBufferPtr buffer = xmlBufferCreate();
        xmlNodeDump(buffer, currentNode->doc, currentNode, 0, 0);
        NSString *rawContent = [NSString stringWithCString:(const char *)buffer->content encoding:NSUTF8StringEncoding];
        if (rawContent != nil) {
            resultForNode[@"raw"] = rawContent;
        }
        //0xcb
        rawContent = nil;
        xmlBufferFree(buffer);
        return resultForNode;
    }
}


@interface ViewController ()
{
    const char *enc;
}
@property (nonatomic, assign) NSInteger spiderCount;
@end

@implementation ViewController

- (void)spiderTest:(NSString *)htmlStr
{
    @autoreleasepool {
        htmlDocPtr htmlDoc = htmlReadDoc((xmlChar *)[htmlStr UTF8String], NULL, enc, XML_PARSE_NOERROR | XML_PARSE_NOWARNING);
         NSMutableDictionary *parentResult = [NSMutableDictionary dictionary];
         __block void (^GetNodeInfo)(xmlNodePtr);
         __block __weak void (^weakGetNodeInfo)(xmlNodePtr);
        
        
        GetNodeInfo = ^(xmlNodePtr aNode) {
            while (aNode != NULL) {
                __unused NSDictionary *retDict = DictionaryForNode(aNode, parentResult, YES);
                //NSLog(@"%@", retDict);
                retDict = nil;
                weakGetNodeInfo(aNode->children);
                aNode = aNode->next;
            }
        };
        weakGetNodeInfo = GetNodeInfo;
        GetNodeInfo((xmlNodePtr)htmlDoc);
        
        
        parentResult = nil;
        xmlFreeDoc(htmlDoc);
    }
    ++self.spiderCount;
    //NSLog(@"spider count ==== %ld", self.spiderCount);
    if (self.spiderCount > 100000) {
        NSLog(@"结束测试");
        exit(0);
        //return;
    }else {
        //[self spiderTest:htmlStr];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    
    NSString *htmlStr = [NSString stringWithContentsOfURL:[NSURL URLWithString:@"https://github.com"]];
    NSLog(@"解析html === %@", htmlStr);
    CFStringEncoding cfenc = CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding);
    CFStringRef cfencstr = CFStringConvertEncodingToIANACharSetName(cfenc);
    enc = CFStringGetCStringPtr(cfencstr, 0);
    
    //递归消耗太多系统调用栈资源，内存也会上去
//    [self spiderTest:htmlStr];
    
    //不能用递归，用循环,多次调用系统会回收不影响内存
    while (true) {
        [self spiderTest:htmlStr];
    }
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
