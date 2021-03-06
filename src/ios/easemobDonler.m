#import "easemobDonler.h"
#import "ChatSendHelper.h"
#import "EMChatManagerDelegateBase.h"
#import <AVFoundation/AVFoundation.h>

@interface easemobDonler()<IChatManagerDelegate>{

}
@property NSString *currentUser;
@end
@implementation easemobDonler;

- (void) init:(CDVInvokedUrlCommand *)command
{
    [[EaseMob sharedInstance] registerSDKWithAppKey:@"donler#donlerapp"
                                       apnsCertName:@"55yali"
                                        otherConfig:@{kSDKConfigEnableConsoleLogger:[NSNumber numberWithBool:YES]}];

    [EMCDDeviceManager sharedInstance].delegate = self;
    [[EaseMob sharedInstance].chatManager removeDelegate:self];
    [[EaseMob sharedInstance].chatManager addDelegate:self delegateQueue:nil];
    
}

/**
* login: command.arguments:[username, password];
*/
- (void) login:(CDVInvokedUrlCommand *)command
{
    NSString* username = command.arguments[0];
    NSString* password = command.arguments[1];

    [[EaseMob sharedInstance].chatManager asyncLoginWithUsername:username
                                                        password:password
                                                      completion:
     ^(NSDictionary *loginInfo, EMError *error) {

         if (loginInfo && !error) {
             //获取群组列表
             // [[EaseMob sharedInstance].chatManager asyncFetchMyGroupsList];
             
             self.currentUser = username;
             //设置是否自动登录 
             [[EaseMob sharedInstance].chatManager setIsAutoLoginEnabled:YES];

             CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
             [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
         }
         else
         {
             NSString *errorMessage = [NSString stringWithFormat:@"%ld",(long)error.errorCode];
             CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
             [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
         }
     } onQueue:nil];

}

- (void) logout:(CDVInvokedUrlCommand *)command
{
    [[EaseMob sharedInstance].chatManager asyncLogoffWithUnbindDeviceToken:YES/NO completion:^(NSDictionary *info, EMError *error) {
        if (!error && info) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
        else
        {
            NSString *errorMessage = [NSString stringWithFormat:@"%ld",(long)error.errorCode];
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    } onQueue:nil];
}

/**
* 发送消息
*/
- (void) chat:(CDVInvokedUrlCommand *)command
{
    NSDictionary *args = command.arguments[0];
    NSString* chatType = args[@"chatType"];
    NSString* target = args[@"target"];
    NSDictionary *content = args[@"content"];
    EMMessageType messageType = [self convertToMessageType:chatType];
    EMMessage *tempMessage;
    NSString *contentType = args[@"contentType"];
    NSDictionary *ext = args[@"ext"] ? args[@"ext"]: nil;
    if([contentType isEqualToString:@"TXT"])
    {
        NSString *text = content[@"text"];
        tempMessage = [ChatSendHelper sendTextMessageWithString:text
                                                     toUsername:target
                                                    messageType:messageType
                                              requireEncryption:NO
                                                            ext:ext];
    }
    else if([contentType isEqualToString:@"IMAGE"])
    {
        NSString *path = content[@"filePath"];
        //NSString *referenceURL = [[NSURL fileURLWithPath:path] URLByStandardizingPath];
        NSString *referenceURL = [path substringFromIndex:8];
        //NSURL *urlString = (NSURL *)path;
        //NSData *imageData = [NSData dataWithData:UIImagePNGRepresentation([UIImage imageWithData:[NSData dataWithContentsOfURL:urlString]])];
        //UIImage *image = [UIImage imageWithData:imageData];

        UIImage *image = [[UIImage alloc] initWithContentsOfFile:referenceURL];
        tempMessage = [ChatSendHelper sendImageMessageWithImage:image
                                                     toUsername:target
                                                    messageType:messageType
                                              requireEncryption:NO
                                                            ext:ext];
    }
    else if([contentType isEqualToString:@"VOICE"])
    {
        NSString *recordPath = content[@"filePath"];
        EMChatVoice *voice = [[EMChatVoice alloc] initWithFile:recordPath
                                                   displayName:@"audio"];
        tempMessage = [ChatSendHelper sendVoice:voice
                                     toUsername:target
                                    messageType:messageType
                              requireEncryption:NO
                                            ext:ext];
    }
    NSMutableDictionary *resultMessage = [self formatMessage:tempMessage];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary: resultMessage];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

/**
* 开始录音
*/
- (void) recordstart:(CDVInvokedUrlCommand *)command
{
     if ([self canRecord]) {
         int x = arc4random() % 100000;
         NSTimeInterval time = [[NSDate date] timeIntervalSince1970];
         NSString *fileName = [NSString stringWithFormat:@"%d%d",(int)time,x];
         NSLog(@"%@",fileName);
         [[EMCDDeviceManager sharedInstance] asyncStartRecordingWithFileName:fileName
                                                                  completion:^(NSError *error)
          {
              if (error) {
                  NSLog(NSLocalizedString(@"message.startRecordFail", @"failure to start recording"));
                  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
                  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
              }
              else {
                  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
              }
          }];
     }
}

/**
* 录音结束，发向服务器
*/
- (void) recordend: (CDVInvokedUrlCommand *)command
{
    [[EMCDDeviceManager sharedInstance] asyncStopRecordingWithCompletion:^(NSString *recordPath, NSInteger aDuration, NSError *error) {
        if (!error) {
            NSString *chatType = command.arguments[0];
            NSString* target = command.arguments[1];
            EMMessageType messageType = [self convertToMessageType:chatType];
            EMChatVoice *voice = [[EMChatVoice alloc] initWithFile:recordPath
                                                       displayName:@"audio"];
            voice.duration = aDuration;
            EMMessage *tempMessage = [ChatSendHelper sendVoice:voice
                                                    toUsername:target
                                                   messageType:messageType
                                             requireEncryption:NO ext:nil];
            NSMutableDictionary *resultMessage = [self formatMessage:tempMessage];
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary: resultMessage];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

        }else {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"录音时间太短"];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            });
        }
    }];
}

/**
* 取消录音
*/
- (void) recordcancel: (CDVInvokedUrlCommand *)command
{
    [[EMCDDeviceManager sharedInstance] cancelCurrentRecording];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

/**
* 播放
*/
- (void) playRecord: (CDVInvokedUrlCommand *)command
{
    NSDictionary *args = command.arguments[0];

    NSString *path = args[@"path"];
    [[EMCDDeviceManager sharedInstance] asyncPlayingWithPath:path
                                                  completion:^(NSError *error) {
        if(!error) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
        else{
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    }];

    //以下是更新message的ext属性，标为已听过.
    NSString *chatType = args[@"chatType"];

    EMMessageType messageType = [self convertToMessageType:chatType];
    NSString *chatter = args[@"target"];
    EMConversation *conversation = [[EaseMob sharedInstance].chatManager conversationForChatter:chatter conversationType:messageType];
    NSString *msgId = args[@"msgId"];
    EMMessage *message = [conversation loadMessageWithId:msgId];
    
    if(!message.ext) {
        message.ext = [NSMutableDictionary dictionary];
    }
    NSMutableDictionary *dict = [message.ext mutableCopy];
    if (![dict[@"isPlayed"] boolValue]) {
        [dict setObject:@YES forKey:@"isPlayed"];
        message.ext = dict;
        [message updateMessageExtToDB];
    }
}

/**
* 停止播放
*/
- (void) stopPlayRecord: (CDVInvokedUrlCommand *)command
{
    [[EMCDDeviceManager sharedInstance] stopPlaying];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}
/**
* 收到在线消息
*/
- (void)didReceiveMessage:(EMMessage *)message
{
    NSLog (@"%@", message);
    id<IEMMessageBody> msgBody = message.messageBodies.firstObject;
    //如果是语音、图片，等下载完缩略图或语音后再发到前台，以免听不到。
    if(msgBody.messageBodyType != eMessageBodyType_Image && msgBody.messageBodyType != eMessageBodyType_Voice){
        NSMutableDictionary *resultMessage = [self formatMessage:message];
        NSError  *error;
        NSData   *jsonData   = [NSJSONSerialization dataWithJSONObject:resultMessage options:0 error:&error];
        NSString *jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
        [self.commandDelegate evalJs:[NSString stringWithFormat:@"window.easemob.onReciveMessage(%@)",jsonString]];
    }
}

/**
* SDK接收到消息时, 下载附件成功或失败的回调
*/
- (void)didMessageAttachmentsStatusChanged :(EMMessage *)message error:(EMError *)error
{
    NSMutableDictionary *resultMessage = [self formatMessage:message];
    //如果出错也返回，等到下载大图时判断小图是否未下载如果未下载去下载小图
    NSError  *jerror;
    NSData   *jsonData   = [NSJSONSerialization dataWithJSONObject:resultMessage options:0 error:&jerror];
    NSString *jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
    [self.commandDelegate evalJs:[NSString stringWithFormat:@"window.easemob.onReciveMessage(%@)",jsonString]];
}

- (void)didReceiveCmdMessage:(EMMessage *)cmdMessage
{
    NSLog (@"%@", cmdMessage);
    NSMutableDictionary *resultMessage = [self formatMessage:cmdMessage];
    NSError  *error;
    NSData   *jsonData   = [NSJSONSerialization dataWithJSONObject:resultMessage options:0 error:&error];
    NSString *jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
    [self.commandDelegate evalJs:[NSString stringWithFormat:@"window.easemob.onReciveCmdMessage(%@)",jsonString]];
}

/**
* 收到离线消息
*/
- (void)didFinishedReceiveOfflineMessages:(NSArray *)offlineMessages
{
    NSLog (@"%@", offlineMessages);
    NSMutableArray *resultMessages = [self formatMessages:offlineMessages];
    NSError  *error;
    NSData   *jsonData   = [NSJSONSerialization dataWithJSONObject:resultMessages options:0 error:&error];
    NSString *jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
    [self.commandDelegate evalJs:[NSString stringWithFormat:@"window.easemob.onReciveOfflineMessages(%@)",jsonString]];
}


/**
* 消息发送返回结果
*/
-(void)didSendMessage:(EMMessage *)message error:(EMError *)error
{
    NSMutableDictionary *resultMessage = [self formatMessage:message];
    NSError  *jerror;
    NSData   *jsonData   = [NSJSONSerialization dataWithJSONObject:resultMessage options:0 error:&jerror];
    NSString *jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
    [self.commandDelegate evalJs:[NSString stringWithFormat:@"window.easemob.onReciveMessage(%@)",jsonString]];
}

/**
* 获取会话列表
*/
- (void) getAllConversations: (CDVInvokedUrlCommand *)command
{
    NSMutableArray *chatListResult = [self formatChatList];
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:chatListResult];
    [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
}

/**
* 获取某会话的聊天记录
*/
- (void) getMessages: (CDVInvokedUrlCommand *)command
{
    NSString *chatType = command.arguments[0];
    EMMessageType messageType = [self convertToMessageType:chatType];
    NSString *chatter = command.arguments[1];
    EMConversation *conversation = [[EaseMob sharedInstance].chatManager conversationForChatter:chatter conversationType:messageType];
    NSString *messageId = command.arguments.count ==3 ? command.arguments[2] : nil;
    NSArray *messages = [conversation loadNumbersOfMessages:20 withMessageId:messageId];
    NSMutableArray *retMessages = [self formatMessages:messages];
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:retMessages];
    [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
}

/**
* 清零未读数
*/
- (void) resetUnreadMsgCount: (CDVInvokedUrlCommand *)command
{
    NSString *chatType = command.arguments[0];
    EMMessageType messageType = [self convertToMessageType:chatType];
    NSString *chatter = command.arguments[1];
    EMConversation *conversation = [[EaseMob sharedInstance].chatManager conversationForChatter:chatter conversationType:messageType];
    [conversation markAllMessagesAsRead: 1];
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
}

/**
* 清零会话聊天记录
*/
- (void) clearConversation: (CDVInvokedUrlCommand *)command
{
    NSString *chatType = command.arguments[0];
    EMMessageType messageType = [self convertToMessageType:chatType];
    NSString *chatter = command.arguments[1];
    EMConversation *conversation = [[EaseMob sharedInstance].chatManager conversationForChatter:chatter conversationType:messageType];
    [conversation removeAllMessages];
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
}
/**
* 删除会话及聊天记录
*/
- (void) deleteConversation: (CDVInvokedUrlCommand *)command
{
    NSString *chatType = command.arguments[0];
    EMMessageType messageType = [self convertToMessageType:chatType];
    NSString *chatter = command.arguments[1];
    [[EaseMob sharedInstance].chatManager removeConversationByChatter:chatter deleteMessages:YES append2Chat:false];
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
}
/**
* 删除会话某条聊天记录
*/
- (void) deleteMessage: (CDVInvokedUrlCommand *)command
{
    NSString *chatType = command.arguments[0];
    EMMessageType messageType = [self convertToMessageType:chatType];
    NSString *chatter = command.arguments[1];
    EMConversation *conversation = [[EaseMob sharedInstance].chatManager conversationForChatter:chatter conversationType:messageType];
    NSString *msgId = command.arguments[2];
    [conversation removeMessageWithId: msgId];
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
}

/**
* 下载附件,返回新的message对象.
*/
- (void) downloadMessage: (CDVInvokedUrlCommand *)command
{
    NSString *chatType = command.arguments[0];
    EMMessageType messageType = [self convertToMessageType:chatType];
    NSString *chatter = command.arguments[1];
    EMConversation *conversation = [[EaseMob sharedInstance].chatManager conversationForChatter:chatter conversationType:messageType];
    NSString *msgId = command.arguments[2];
    EMMessage *message = [conversation loadMessageWithId:msgId];
    id <IChatManager> chatManager = [[EaseMob sharedInstance] chatManager];
    [chatManager asyncFetchMessage:message progress:nil completion:^(EMMessage *aMessage, EMError *error) {
        if(!error)
        {
            NSMutableDictionary *resultMessage = [self formatMessage:aMessage];
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary: resultMessage];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
        else
        {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    }onQueue:nil];
}

/**
* 下载小图接口
*/
- (void) downloadThumbnail: (CDVInvokedUrlCommand *)command
{
    NSString *chatType = command.arguments[0];
    EMMessageType messageType = [self convertToMessageType:chatType];
    NSString *chatter = command.arguments[1];
    EMConversation *conversation = [[EaseMob sharedInstance].chatManager conversationForChatter:chatter conversationType:messageType];
    NSString *msgId = command.arguments[2];
    EMMessage *message = [conversation loadMessageWithId:msgId];
    [[EaseMob sharedInstance].chatManager asyncFetchMessageThumbnail:message progress:nil completion:^(EMMessage *aMessage, EMError *error) {
        NSMutableDictionary *resultMessage = [self formatMessage:aMessage];
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary: resultMessage];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }onQueue:nil];
}


/**
* 字符串转换为EMMessageType
*/
- (EMMessageType) convertToMessageType: (NSString *)chatType
{
    EMMessageType messageType;
    if([chatType isEqualToString:@"single"])
    {
        messageType = eMessageTypeChat;
    }
    else
    {
        messageType = eMessageTypeGroupChat;
    }
    return messageType;
}

/**
* 格式化列表
*/
- (NSMutableArray *)formatChatList
{
    NSArray *chatList = [[EaseMob sharedInstance].chatManager loadAllConversationsFromDatabaseWithAppend2Chat:NO];
    //排序
    NSArray* sorte = [chatList sortedArrayUsingComparator:
            ^(EMConversation *obj1, EMConversation* obj2){
                EMMessage *message1 = [obj1 latestMessage];
                EMMessage *message2 = [obj2 latestMessage];
                if(message1.timestamp > message2.timestamp) {
                    return(NSComparisonResult)NSOrderedAscending;
                }else {
                    return(NSComparisonResult)NSOrderedDescending;
                }
            }];

    NSMutableArray *sotedChatlist = [[NSMutableArray alloc] initWithArray:sorte];

    NSMutableArray *ret = [NSMutableArray array];
    for(int i=0; i< sotedChatlist.count; i++){
        NSMutableDictionary *retGroup = [NSMutableDictionary dictionaryWithCapacity:10];
        EMConversation *temp = sotedChatlist[i];
        //todo 格式待定
        //会话对方的用户名. 如果是群聊, 则是群组的id
        retGroup[@"chatter"] = temp.chatter;
        //是否是群聊
        NSNumber *isGroup = @(temp.isGroup);
        retGroup[@"isGroup"] = isGroup;
        //最新消息
        if(temp.latestMessage) {
            retGroup[@"latestMessage"] = [self formatMessage:temp.latestMessage];
        }
        //未读数
        NSNumber *unreadMessagesCount = @(temp.unreadMessagesCount);
        retGroup[@"unreadMessagesCount"] = unreadMessagesCount;
        [ret addObject:retGroup];
    }
    return ret;
}

- (BOOL)canRecord
{
    __block BOOL bCanRecord = YES;
    if ([[[UIDevice currentDevice] systemVersion] compare:@"7.0"] != NSOrderedAscending)
    {
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        if ([audioSession respondsToSelector:@selector(requestRecordPermission:)]) {
            [audioSession performSelector:@selector(requestRecordPermission:) withObject:^(BOOL granted) {
                bCanRecord = granted;
            }];
        }
    }

    return bCanRecord;
}

/**
* 格式化每条信息
*/
- (NSMutableArray *)formatMessages: (NSArray*)originMessages
{
    NSMutableArray * resultMessages = [NSMutableArray array];
    for(int i=0; i<originMessages.count; i++) {
        [resultMessages addObject:[self formatMessage:originMessages[i]]];
    }
    return resultMessages;
}

/**
* 格式化一条信息
*/
- (NSMutableDictionary *)formatMessage:(EMMessage *)tempMessage
{
    NSMutableDictionary *resultMessage = [NSMutableDictionary dictionaryWithCapacity:10];

    id type ;
    //todo:换实现
    switch (tempMessage.messageType) {
        case eMessageTypeChat:{
            type = @"Chat";
        };
        break;
        case eMessageTypeGroupChat:{
            type = @"GroupChat";
        };
        break;
        case eMessageTypeChatRoom:{
            type = @"ChatRoom";
        };
        default: {
            type = @"?";
        }
    }
    //基本属性
    resultMessage[@"chatType"] = type;
    if ([type isEqualToString:@"Chat"] || [tempMessage.from isEqualToString:self.currentUser]) {
        resultMessage[@"to"] = tempMessage.to;
        resultMessage[@"from"] = tempMessage.from;
    }
    else {
        resultMessage[@"to"] = tempMessage.from;
        resultMessage[@"from"] = tempMessage.groupSenderName;
    }
    resultMessage[@"msgId"] = tempMessage.messageId;
    resultMessage[@"msgTime"] = @(tempMessage.timestamp);
    resultMessage[@"unRead"] = @(!tempMessage.isRead);
    id status = [self formatState:tempMessage.deliveryState];
    resultMessage[@"status"] = status;
    NSNumber *isAcked = @(!tempMessage.isReadAcked);
    resultMessage[@"isAcked"] = isAcked;
    //progress 无
    tempMessage.ext ? resultMessage[@"ext"] = [tempMessage.ext mutableCopy] : nil;
    //body
    id<IEMMessageBody> msgBody = tempMessage.messageBodies.firstObject;
    resultMessage[@"type"] = [self formatType:msgBody.messageBodyType];
    NSMutableDictionary *messageBody = [NSMutableDictionary dictionaryWithCapacity:10];;
    switch (msgBody.messageBodyType) {
        case eMessageBodyType_Text:{
            NSString *txt = ((EMTextMessageBody *)msgBody).text;
            messageBody[@"text"] = txt;
        };
        break;
        case eMessageBodyType_Image:{
            EMImageMessageBody *body = ((EMImageMessageBody *)msgBody);
            //大图remote路径
            //[messageBody setObject:body.remotePath forKey:@"remoteUrl"];
            //NSLog(@"大图local路径 -- %@"    ,body.localPath); // // 需要使用sdk提供的下载方法后才会存在
            messageBody[@"localUrl"] = body.localPath;
            //大图的secret
            //[messageBody setObject:body.secretKey forKey:@"secretKey"];
            //大图的H
            NSNumber *height = @(body.size.height);
            messageBody[@"height"] = height;
            //大图的W
            NSNumber *width = @(body.size.width);
            messageBody[@"width"] = width;
            //大图的下载状态
            //[messageBody setObject:body.attachmentDownloadStatus forKey:@"attachmentDownloadStatus"];
            // 缩略图sdk会自动下载
            //小图local路径
            messageBody[@"thumbnailUrl"] = body.thumbnailLocalPath ? body.thumbnailLocalPath: @"";
            //NSLog(@"小图的secret -- %@"    ,body.thumbnailSecretKey);

            //小图的H
            NSNumber *thumbnailHeight = @(body.thumbnailSize.height);
            messageBody[@"thumbnailHeight"] = thumbnailHeight;
            //小图的W
            NSNumber *thumbnailWidth = @(body.thumbnailSize.width);
            messageBody[@"thumbnailWidth"] = thumbnailWidth;
            //NSLog(@"小图的下载状态 -- %lu",body.thumbnailDownloadStatus);
        };
        break;
        case eMessageBodyType_Location:{
            //todo
        };
        break;
        case eMessageBodyType_Voice:{
            EMVoiceMessageBody *body = (EMVoiceMessageBody *)msgBody;
            //NSLog(@"音频remote路径 -- %@"      ,body.remotePath);
            //音频local路径 //需要使用sdk提供的下载方法后才会存在（音频会自动调用）
            messageBody[@"localUrl"] = body.localPath;
            //NSLog(@"音频的secret -- %@"        ,body.secretKey);
            NSNumber *duration = @(body.duration);
            messageBody[@"duration"] = duration;
            //NSLog(@"音频文件大小 -- %lld"       ,body.fileLength);
            //NSLog(@"音频文件的下载状态 -- %lu"   ,body.attachmentDownloadStatus);
            //NSLog(@"音频的时间长度 -- %lu"      ,body.duration);
            if(resultMessage[@"ext"]) {
                messageBody[@"isListened"] = [resultMessage[@"ext"] objectForKey:@"isPlayed"];
            }else {
                messageBody[@"isListened"] = @NO;
            }
        };
    }
    messageBody ? resultMessage[@"body"] = messageBody : nil;
    return resultMessage;
}

/**
* 格式化发送状态
*/
- (NSString *)formatState: (NSInteger)deliveryState
{
    NSString *status;
    switch (deliveryState) {
        case eMessageDeliveryState_Pending:{
            status = @"CREATE";
        };
            break;
        case eMessageDeliveryState_Delivering:{
            status = @"INPROGRESS";
        };
            break;
        case eMessageDeliveryState_Delivered:{
            status = @"SUCCESS";
        };
            break;
        case eMessageDeliveryState_Failure:{
            status = @"FAIL";
        };
            break;
    }
    return status;
}

/**
* 格式化消息类型
*/
- (NSString *)formatType: (NSInteger)messageBodyType
{
    NSString *type;
    switch (messageBodyType) {
        case eMessageBodyType_Text:
            type = @"TXT";
            break;
        case eMessageBodyType_Image:
            type = @"IMAGE";
            break;
        case eMessageBodyType_Voice:
            type = @"VOICE";
            break;
        default:
            type = @"OTHERS";
            break;
    }
    return type;
}

@end