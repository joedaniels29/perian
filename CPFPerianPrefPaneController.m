#import "CPFPerianPrefPaneController.h"
#import "UpdateCheckerAppDelegate.h"
#include <sys/stat.h>

#define AC3DynamicRangeKey CFSTR("dynamicRange")
#define AC3StereoOverDolbyKey CFSTR("useStereoOverDolby")
#define AC3ProLogicIIKey CFSTR("useDolbyProLogicII")
#define LastInstalledVersionKey CFSTR("LastInstalledVersion")

@interface NSString (VersionStringCompare)
- (BOOL)isVersionStringOlderThan:(NSString *)older;
@end

@implementation NSString (VersionStringCompare)
- (BOOL)isVersionStringOlderThan:(NSString *)older
{
	if([self compare:older] == NSOrderedAscending)
		return TRUE;
	if([self hasPrefix:older] && [self length] > [older length] && [self characterAtIndex:[older length]] == 'b')
		//1.0b1 < 1.0, so check for it.
		return TRUE;
	return FALSE;
}
@end

@interface CPFPerianPrefPaneController(_private)
- (void)setAC3DynamicRange:(float)newVal;
- (void)saveAC3DynamicRange:(float)newVal;
@end

@implementation CPFPerianPrefPaneController

#pragma mark Preferences Functions

- (BOOL)getBoolFromKey:(CFStringRef)key forAppID:(CFStringRef)appID withDefault:(BOOL)defaultValue
{
	CFPropertyListRef value;
	BOOL ret = defaultValue;
	
	value = CFPreferencesCopyAppValue(key, appID);
	if(value && CFGetTypeID(value) == CFBooleanGetTypeID())
		ret = CFBooleanGetValue(value);
	
	if(value)
		CFRelease(value);
	
	return ret;
}

- (void)setKey:(CFStringRef)key forAppID:(CFStringRef)appID fromBool:(BOOL)value
{
	CFPreferencesSetAppValue(key, value ? kCFBooleanTrue : kCFBooleanFalse, appID);
}

- (float)getFloatFromKey:(CFStringRef)key forAppID:(CFStringRef)appID withDefault:(float)defaultValue
{
	CFPropertyListRef value;
	float ret = defaultValue;
	
	value = CFPreferencesCopyAppValue(key, appID);
	if(value && CFGetTypeID(value) == CFNumberGetTypeID())
		CFNumberGetValue(value, kCFNumberFloatType, &ret);
	
	if(value)
		CFRelease(value);
	
	return ret;
}

- (void)setKey:(CFStringRef)key forAppID:(CFStringRef)appID fromString:(NSString *)value
{
	CFPreferencesSetAppValue(key, value, appID);
}

- (NSString *)getStringFromKey:(CFStringRef)key forAppID:(CFStringRef)appID
{
	CFPropertyListRef value;
	NSString *ret = nil;
	
	value = CFPreferencesCopyAppValue(key, appID);
	if(value && CFGetTypeID(value) == CFStringGetTypeID())
		ret = [NSString stringWithString:(NSString *)value];
	
	if(value)
		CFRelease(value);
	
	return ret;
}

- (void)setKey:(CFStringRef)key forAppID:(CFStringRef)appID fromFloat:(float)value
{
	CFNumberRef numRef = CFNumberCreate(NULL, kCFNumberFloatType, &value);
	CFPreferencesSetAppValue(key, numRef, appID);
	CFRelease(numRef);
}

#pragma mark Private Functions

- (NSString *)installationBasePath:(BOOL)userInstallation
{
	if(userInstallation)
		return NSHomeDirectory();
	return [NSString stringWithString:@"/"];
}

- (NSString *)quickTimeComponentDir:(BOOL)userInstallation
{
	return [[self installationBasePath:userInstallation] stringByAppendingPathComponent:@"Library/QuickTime"];
}

- (NSString *)coreAudioComponentDir:(BOOL)userInstallation
{
	return [[self installationBasePath:userInstallation] stringByAppendingPathComponent:@"Library/Audio/Plug-Ins/Components"];
}

- (NSString *)frameworkComponentDir:(BOOL)userInstallation
{
	return [[self installationBasePath:userInstallation] stringByAppendingPathComponent:@"Library/Frameworks"];
}

- (NSString *)basePathForType:(ComponentType)type user:(BOOL)userInstallation
{
	NSString *path = nil;
	
	switch(type)
	{
		case ComponentTypeCoreAudio:
			path = [self coreAudioComponentDir:userInstallation];
			break;
		case ComponentTypeQuickTime:
			path = [self quickTimeComponentDir:userInstallation];
			break;
		case ComponentTypeFramework:
			path = [self frameworkComponentDir:userInstallation];
			break;
	}
	return path;
}

- (InstallStatus)installStatusForComponent:(NSString *)component type:(ComponentType)type withMyVersion:(NSString *)myVersion
{
	NSString *path = nil;
	InstallStatus ret = InstallStatusNotInstalled;
	
	path = [[self basePathForType:type user:userInstalled] stringByAppendingPathComponent:component];
	
	NSDictionary *infoDict = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Contents/Info.plist"]];
	if(infoDict != nil)
	{
		NSString *currentVersion = [infoDict objectForKey:BundleVersionKey];
		if([currentVersion isVersionStringOlderThan:myVersion])
			ret = InstallStatusOutdated;
		else
			ret = InstallStatusInstalled;
	}
	
	/* Check other installation type */
	path = [[self basePathForType:type user:!userInstalled] stringByAppendingPathComponent:component];
	
	infoDict = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Contents/Info.plist"]];
	if(infoDict == nil)
		/* Above result is all there is */
		return ret;
	
	return setWrongLocationInstalled(ret);
}

- (void)setInstalledVersionString
{
	NSString *path = [[self basePathForType:ComponentTypeQuickTime user:userInstalled] stringByAppendingPathComponent:@"Perian.component"];
	
	NSDictionary *infoDict = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Contents/Info.plist"]];
	if(infoDict != nil)
	{
		NSString *currentVersion = [infoDict objectForKey:BundleVersionKey];
		[textField_currentVersion setStringValue:currentVersion];
	}
	else
		[textField_currentVersion setStringValue:@"-"];
}

#pragma mark Preference Pane Support

- (id)initWithBundle:(NSBundle *)bundle
{
	if ( ( self = [super initWithBundle:bundle] ) != nil ) {
		perianForumURL = [[NSURL alloc] initWithString:@"http://forums.cocoaforge.com/index.php?c=12"];
		perianDonateURL = [[NSURL alloc] initWithString:@"http://perian.org"];
		perianWebSiteURL = [[NSURL alloc] initWithString:@"http://perian.org"];
		
		perianAppID = CFSTR("org.perian.Perian");
		a52AppID = CFSTR("com.cod3r.a52codec");
		
		NSString *myPath = [[self bundle] bundlePath];
		
		if([myPath hasPrefix:@"/Library"])
			userInstalled = NO;
		else
			userInstalled = YES;
	}
	
	return self;
}

- (void)checkForInstallation
{
	NSDictionary *infoDict = [[self bundle] infoDictionary];
	NSString *myVersion = [infoDict objectForKey:BundleVersionKey];
	
	[self setInstalledVersionString];
	installStatus = [self installStatusForComponent:@"Perian.component" type:ComponentTypeQuickTime withMyVersion:myVersion];
	if(currentInstallStatus(installStatus) == InstallStatusNotInstalled)
	{
		[textField_installStatus setStringValue:NSLocalizedString(@"Perian is not Installed", @"")];
		[button_install setTitle:NSLocalizedString(@"Install Perian", @"")];
	}
	else if(currentInstallStatus(installStatus) == InstallStatusOutdated)
	{
		[textField_installStatus setStringValue:NSLocalizedString(@"Perian is Installed, but Outdated", @"")];
		[button_install setTitle:NSLocalizedString(@"Update Perian", @"")];
	}
	else
	{
		//Perian is fine, but check components
		NSDictionary *myComponentsInfo = [infoDict objectForKey:ComponentInfoDictionaryKey];
		if(myComponentsInfo != nil)
		{
			NSEnumerator *componentEnum = [myComponentsInfo objectEnumerator];
			NSDictionary *componentInfo = nil;
			while((componentInfo = [componentEnum nextObject]) != nil)
			{
				InstallStatus tstatus = [self installStatusForComponent:[componentInfo objectForKey:ComponentNameKey] type:[[componentInfo objectForKey:ComponentTypeKey] intValue] withMyVersion:[componentInfo objectForKey:BundleVersionKey]];
				if(tstatus < installStatus)
					installStatus = tstatus;
			}
			switch(installStatus)
			{
				case InstallStatusInstalledInWrongLocation:
				case InstallStatusNotInstalled:
					[textField_installStatus setStringValue:NSLocalizedString(@"Perian is Installed, but parts are Not Installed", @"")];
					[button_install setTitle:NSLocalizedString(@"Install Perian", @"")];
					break;
				case InstallStatusOutdatedWithAnotherInWrongLocation:
				case InstallStatusOutdated:
					[textField_installStatus setStringValue:NSLocalizedString(@"Perian is Installed, but parts are Outdated", @"")];
					[button_install setTitle:NSLocalizedString(@"Update Perian", @"")];
					break;
				case InstallStatusInstalledInBothLocations:
					[textField_installStatus setStringValue:NSLocalizedString(@"Perian is Installed Twice", @"")];
					[button_install setTitle:NSLocalizedString(@"Correct Installation", @"")];
					break;
				case InstallStatusInstalled:
					[textField_installStatus setStringValue:NSLocalizedString(@"Perian is Installed", @"")];
					[button_install setTitle:NSLocalizedString(@"Remove Perian", @"")];
					break;
			}
		}
		else if(isWrongLocationInstalled(installStatus))
		{
			[textField_installStatus setStringValue:NSLocalizedString(@"Perian is Installed Twice", @"")];
			[button_install setTitle:NSLocalizedString(@"Correct Installation", @"")];
		}
		else
		{
			[textField_installStatus setStringValue:NSLocalizedString(@"Perian is Installed", @"")];
			[button_install setTitle:NSLocalizedString(@"Remove Perian", @"")];
		}
		
	}
}

- (void)didSelect
{
	/* General */
	[self checkForInstallation];
	NSString *lastInstVersion = [self getStringFromKey:LastInstalledVersionKey forAppID:perianAppID];
	NSString *myVersion = [[[self bundle] infoDictionary] objectForKey:BundleVersionKey];
	if((lastInstVersion == nil || [lastInstVersion isVersionStringOlderThan:myVersion]) && installStatus != InstallStatusInstalled)
	{
		/*Check for temp after an update */
		BOOL isDir = NO;
		NSString *tempPrefPane = [NSTemporaryDirectory() stringByAppendingPathComponent:@"PerianPane.prefPane"];
		int tag;
		
		if([[NSFileManager defaultManager] fileExistsAtPath:tempPrefPane isDirectory:&isDir] && isDir)
			[[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:[tempPrefPane stringByDeletingLastPathComponent] destination:@"" files:[NSArray arrayWithObject:[tempPrefPane lastPathComponent]] tag:&tag];
		
		[self installUninstall:nil];
		[self setKey:LastInstalledVersionKey forAppID:perianAppID fromString:myVersion];
	}
	
	NSDate *updateDate = (NSDate *)CFPreferencesCopyAppValue((CFStringRef)NEXT_RUN_KEY, perianAppID);
	if([updateDate timeIntervalSinceNow] > 1000000000) //futureDate
		[button_autoUpdateCheck setIntValue:0];
	else
		[button_autoUpdateCheck setIntValue:1];
	[updateDate release];
	
	/* A52 Prefs */
	if([self getBoolFromKey:AC3StereoOverDolbyKey forAppID:a52AppID withDefault:NO])
	{
		[popup_2ChannelMode selectItemAtIndex:0];
	}
	else if([self getBoolFromKey:AC3ProLogicIIKey forAppID:a52AppID withDefault:NO])
	{
		[popup_2ChannelMode selectItemAtIndex:2];
	}
	else
	{
		[popup_2ChannelMode selectItemAtIndex:1];		
	}	
	[self setAC3DynamicRange:[self getFloatFromKey:AC3DynamicRangeKey forAppID:a52AppID withDefault:1.0]];
}

- (void)didUnselect
{
	CFPreferencesAppSynchronize(perianAppID);
	CFPreferencesAppSynchronize(a52AppID);
}

- (void) dealloc {
	[perianForumURL release];
	[perianDonateURL release];
	[perianWebSiteURL release];
	if(auth != nil)
		AuthorizationFree(auth, 0);
	[errorString release];
	[super dealloc];
}

#pragma mark Install/Uninstall

/* Shamelessly ripped from Sparkle */
- (BOOL)_extractArchivePath:archivePath toDestination:(NSString *)destination finalPath:(NSString *)finalPath
{
	BOOL ret = NO, oldExist = NO;
	struct stat sb;
	
	if(stat([finalPath fileSystemRepresentation], &sb) == 0)
		oldExist = YES;
	
	char *buf = NULL;
	if(oldExist)
		asprintf(&buf,
				 "mv -f \"$DST_COMPONENT\" \"$TMP_PATH\" && "
				 "ditto -x -k --rsrc \"$SRC_ARCHIVE\" \"$DST_PATH\" && "
				 "rm -rf \"$TMP_PATH\"");
	else
		asprintf(&buf,
				 "mkdir -p \"$DST_PATH\" && "
				 "ditto -x -k --rsrc \"$SRC_ARCHIVE\" \"$DST_PATH\"");
	if(!buf)
	{
		[errorString appendFormat:NSLocalizedString(@"Could not allocate memory for extraction command\n", @"")];
		return FALSE;
	}
	
	setenv("SRC_ARCHIVE", [archivePath fileSystemRepresentation], 1);
	setenv("DST_PATH", [destination fileSystemRepresentation], 1);
	setenv("DST_COMPONENT", [finalPath fileSystemRepresentation], 1);
	setenv("TMP_PATH", [[finalPath stringByAppendingPathExtension:@"old"] fileSystemRepresentation], 1);

	int status = system(buf);
	if(WIFEXITED(status) && WEXITSTATUS(status) == 0)
		ret = YES;
	else
		[errorString appendFormat:NSLocalizedString(@"Extraction for %@ failed\n", @""), archivePath];

	free(buf);
	unsetenv("SRC_ARCHIVE");
	unsetenv("$DST_COMPONENT");
	unsetenv("TMP_PATH");
	unsetenv("DST_PATH");
	return ret;
}

- (BOOL)_authenticatedExtractArchivePath:(NSString *)archivePath toDestination:(NSString *)destination finalPath:(NSString *)finalPath
{
	BOOL ret = NO, oldExist = NO;
	struct stat sb;
	if(stat([finalPath fileSystemRepresentation], &sb) == 0)
		oldExist = YES;
	
	char *buf = NULL;
	if(oldExist)
		asprintf(&buf,
				 "mv -f \"$DST_COMPONENT\" \"$TMP_PATH\" && "
				 "ditto -x -k --rsrc \"$SRC_ARCHIVE\" \"$DST_PATH\" && "
				 "rm -rf \"$TMP_PATH\" && "
				 "chown -R %d:%d \"$DST_COMPONENT\"",
				 sb.st_uid, sb.st_gid);
	else
		asprintf(&buf,
				 "mkdir -p \"$DST_PATH\" && "
				 "ditto -x -k --rsrc \"$SRC_ARCHIVE\" \"$DST_PATH\" && "
				 "chown -R %d:%d \"$DST_COMPONENT\"",
				 sb.st_uid, sb.st_gid);
	if(!buf)
	{
		[errorString appendFormat:NSLocalizedString(@"Could not allocate memory for extraction command\n", @"")];
		return FALSE;
	}
	
	setenv("SRC_ARCHIVE", [archivePath fileSystemRepresentation], 1);
	setenv("DST_COMPONENT", [finalPath fileSystemRepresentation], 1);
	setenv("TMP_PATH", [[finalPath stringByAppendingPathExtension:@"old"] fileSystemRepresentation], 1);
	setenv("DST_PATH", [destination fileSystemRepresentation], 1);
	
	char* arguments[] = { "-c", buf, NULL };
	if(AuthorizationExecuteWithPrivileges(auth, "/bin/sh", kAuthorizationFlagDefaults, arguments, NULL) == errAuthorizationSuccess)
	{
		int status;
		int pid = wait(&status);
		if(pid != -1 && WIFEXITED(status) && WEXITSTATUS(status) == 0)
			ret = YES;
		else
			[errorString appendFormat:NSLocalizedString(@"Extraction for %@ failed\n", @""), archivePath];
	}
	else
		[errorString appendFormat:NSLocalizedString(@"Authentication failed for extraction for %@\n", @""), archivePath];
	
	free(buf);
	unsetenv("SRC_ARCHIVE");
	unsetenv("$DST_COMPONENT");
	unsetenv("TMP_PATH");
	unsetenv("DST_PATH");
	return ret;
}

- (BOOL)_authenticatedRemove:(NSString *)componentPath
{
	BOOL ret = NO;
	struct stat sb;
	if(stat([componentPath fileSystemRepresentation], &sb) != 0)
		/* No error, just forget it */
		return FALSE;
	
	char *buf = NULL;
	asprintf(&buf,
			 "rm -rf \"$COMP_PATH\"");
	if(!buf)
	{
		[errorString appendFormat:NSLocalizedString(@"Could not allocate memory for removal command\n", @"")];
		return FALSE;
	}
	
	setenv("COMP_PATH", [componentPath fileSystemRepresentation], 1);
	
	char* arguments[] = { "-c", buf, NULL };
	if(AuthorizationExecuteWithPrivileges(auth, "/bin/sh", kAuthorizationFlagDefaults, arguments, NULL) == errAuthorizationSuccess)
	{
		int status;
		int pid = wait(&status);
		if(pid != -1 && WIFEXITED(status) && WEXITSTATUS(status) == 0)
			ret = YES;
		else
			[errorString appendFormat:NSLocalizedString(@"Removal for %@ failed\n", @""), componentPath];
	}
	else
		[errorString appendFormat:NSLocalizedString(@"Authentication failed for removal for %@\n", @""), componentPath];
	free(buf);
	unsetenv("COMP_PATH");
	return ret;
}


- (BOOL)installArchive:(NSString *)archivePath forPiece:(NSString *)component type:(ComponentType)type withMyVersion:(NSString *)myVersion
{
	NSString *containingDir = [self basePathForType:type user:userInstalled];
	BOOL ret = YES;

	InstallStatus pieceStatus = [self installStatusForComponent:component type:type withMyVersion:myVersion];
	if(!userInstalled && currentInstallStatus(pieceStatus) != InstallStatusInstalled)
	{
		BOOL result = [self _authenticatedExtractArchivePath:archivePath toDestination:containingDir finalPath:[containingDir stringByAppendingPathComponent:component]];
		if(result == NO)
			ret = NO;
	}
	else
	{
		//Not authenticated
		if(currentInstallStatus(pieceStatus) == InstallStatusOutdated)
		{
			//Remove the old one here
			int tag = 0;
			BOOL result = [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:containingDir destination:@"" files:[NSArray arrayWithObject:component] tag:&tag];
			if(result == NO)
				ret = NO;
		}
		if(currentInstallStatus(pieceStatus) != InstallStatusInstalled)
		{
			//Decompress and install new one
			BOOL result = [self _extractArchivePath:archivePath toDestination:containingDir finalPath:[containingDir stringByAppendingPathComponent:component]];
			if(result == NO)
				ret = NO;
		}		
	}
	if(ret != NO && isWrongLocationInstalled(pieceStatus) != 0)
	{
		/* Let's try and remove the wrong one, if we can, but only if install succeeded */
		containingDir = [self basePathForType:type user:!userInstalled];

		if(userInstalled)
			[self _authenticatedRemove:[containingDir stringByAppendingPathComponent:component]];
		else
		{
			int tag = 0;
			[[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:containingDir destination:@"" files:[NSArray arrayWithObject:component] tag:&tag];
		}
	}
	return ret;
}

- (void)install:(id)sender
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSDictionary *infoDict = [[self bundle] infoDictionary];
	NSDictionary *myComponentsInfo = [infoDict objectForKey:ComponentInfoDictionaryKey];
	NSString *componentPath = [[[self bundle] resourcePath] stringByAppendingPathComponent:@"Components"];
	NSString *coreAudioComponentPath = [componentPath stringByAppendingPathComponent:@"CoreAudio"];
	NSString *quickTimeComponentPath = [componentPath stringByAppendingPathComponent:@"QuickTime"];
	NSString *frameworkComponentPath = [componentPath stringByAppendingPathComponent:@"Frameworks"];

	[errorString release];
	errorString = [[NSMutableString alloc] init];
	/* This doesn't ask the user, so create it anyway.  If we don't need it, no problem */
	if(AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &auth) != errAuthorizationSuccess)
		/* Oh well, hope we don't need it */
		auth = nil;
	
	[self installArchive:[componentPath stringByAppendingPathComponent:@"Perian.zip"] forPiece:@"Perian.component" type:ComponentTypeQuickTime withMyVersion:[infoDict objectForKey:BundleVersionKey]];
	
	NSEnumerator *componentEnum = [myComponentsInfo objectEnumerator];
	NSDictionary *myComponent = nil;
	while((myComponent = [componentEnum nextObject]) != nil)
	{
		NSString *archivePath = nil;
		ComponentType type = [[myComponent objectForKey:ComponentTypeKey] intValue];
		switch(type)
		{
			case ComponentTypeCoreAudio:
				archivePath = [coreAudioComponentPath stringByAppendingPathComponent:[myComponent objectForKey:ComponentArchiveNameKey]];
				break;
			case ComponentTypeQuickTime:
				archivePath = [quickTimeComponentPath stringByAppendingPathComponent:[myComponent objectForKey:ComponentArchiveNameKey]];
				break;
			case ComponentTypeFramework:
				archivePath = [frameworkComponentPath stringByAppendingPathComponent:[myComponent objectForKey:ComponentArchiveNameKey]];
				break;
		}
		[self installArchive:archivePath forPiece:[myComponent objectForKey:ComponentNameKey] type:type withMyVersion:[myComponent objectForKey:BundleVersionKey]];
	}
	if(auth != nil)
	{
		AuthorizationFree(auth, 0);
		auth = nil;
	}
	[self performSelectorOnMainThread:@selector(installComplete:) withObject:nil waitUntilDone:NO];
	[pool release];
}

- (void)uninstall:(id)sender
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSDictionary *infoDict = [[self bundle] infoDictionary];
	NSDictionary *myComponentsInfo = [infoDict objectForKey:ComponentInfoDictionaryKey];

	[errorString release];
	errorString = [[NSMutableString alloc] init];
	/* This doesn't ask the user, so create it anyway.  If we don't need it, no problem */
	if(AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &auth) != errAuthorizationSuccess)
		/* Oh well, hope we don't need it */
		auth = nil;
	
	int tag = 0;
	BOOL result = NO;
	if(auth != nil && !userInstalled)
		[self _authenticatedRemove:[[self quickTimeComponentDir:userInstalled] stringByAppendingPathComponent:@"Perian.component"]];
	else
		result = [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:[self quickTimeComponentDir:userInstalled] destination:@"" files:[NSArray arrayWithObject:@"Perian.component"] tag:&tag];
	
	NSEnumerator *componentEnum = [myComponentsInfo objectEnumerator];
	NSDictionary *myComponent = nil;
	while((myComponent = [componentEnum nextObject]) != nil)
	{
		ComponentType type = [[myComponent objectForKey:ComponentTypeKey] intValue];
		NSString *directory = [self basePathForType:type user:userInstalled];
		if(auth != nil && !userInstalled)
			[self _authenticatedRemove:[directory stringByAppendingPathComponent:[myComponent objectForKey:ComponentNameKey]]];
		else
			result = [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:directory destination:@"" files:[NSArray arrayWithObject:[myComponent objectForKey:ComponentNameKey]] tag:&tag];
	}
	if(auth != nil)
	{
		AuthorizationFree(auth, 0);
		auth = nil;
	}
	
	[self performSelectorOnMainThread:@selector(installComplete:) withObject:nil waitUntilDone:NO];
	[pool release];
}

- (IBAction)installUninstall:(id)sender
{
	[progress_install startAnimation:sender];
	if(installStatus == InstallStatusInstalled)
		[NSThread detachNewThreadSelector:@selector(uninstall:) toTarget:self withObject:nil];
	else
		[NSThread detachNewThreadSelector:@selector(install:) toTarget:self withObject:nil];
}

- (void)installComplete:(id)sender
{
	[progress_install stopAnimation:sender];
	[self checkForInstallation];
}

#pragma mark Check Updates
- (IBAction)updateCheck:(id)sender 
{
	FSRef updateCheckRef;
	
	CFPreferencesSetAppValue((CFStringRef)NEXT_RUN_KEY, NULL, perianAppID);
	OSStatus status = FSPathMakeRef((UInt8 *)[[[[self bundle] bundlePath] stringByAppendingPathComponent:@"Contents/Resources/PerianUpdateChecker.app"] fileSystemRepresentation], &updateCheckRef, NULL);
	if(status != noErr)
		return;
	
	LSOpenFSRef(&updateCheckRef, NULL);
} 

- (IBAction)setAutoUpdateCheck:(id)sender 
{
	CFStringRef key = (CFStringRef)NEXT_RUN_KEY;
	if([button_autoUpdateCheck intValue])
		CFPreferencesSetAppValue(key, [NSDate dateWithTimeIntervalSinceNow:TIME_INTERVAL_TIL_NEXT_RUN], perianAppID);
	else
		CFPreferencesSetAppValue(key, [NSDate distantFuture], perianAppID);
} 


#pragma mark AC3 
- (IBAction)setAC3DynamicRangePopup:(id)sender
{
	int selected = [popup_ac3DynamicRangeType indexOfSelectedItem];
	switch(selected)
	{
		case 0:
			[self saveAC3DynamicRange:1.0];
			break;
		case 1:
			[self saveAC3DynamicRange:2.0];
			break;
		case 3:
			[NSApp beginSheet:window_dynRangeSheet modalForWindow:[[self mainView] window] modalDelegate:nil didEndSelector:nil contextInfo:NULL];
			break;
		default:
			break;
	}
}

- (IBAction)set2ChannelModePopup:(id)sender;
{
	int selected = [popup_2ChannelMode indexOfSelectedItem];
	switch(selected)
	{
		case 0:
			[self setKey:AC3StereoOverDolbyKey forAppID:a52AppID fromBool:YES];
			[self setKey:AC3ProLogicIIKey forAppID:a52AppID fromBool:NO];
			break;
		case 1:
			[self setKey:AC3StereoOverDolbyKey forAppID:a52AppID fromBool:NO];
			[self setKey:AC3ProLogicIIKey forAppID:a52AppID fromBool:NO];
			break;
		case 2:
			[self setKey:AC3StereoOverDolbyKey forAppID:a52AppID fromBool:NO];
			[self setKey:AC3ProLogicIIKey forAppID:a52AppID fromBool:YES];
			break;
		default:
			break;
	}	
}

- (void)setAC3DynamicRange:(float)newVal
{
	if(newVal > 4.0)
		newVal = 4.0;
	if(newVal < 0.0)
		newVal = 0.0;
	
	nextDynValue = newVal;
	[textField_ac3DynamicRangeValue setFloatValue:newVal];
	[slider_ac3DynamicRangeSlider setFloatValue:newVal];
	if(newVal == 1.0)
		[popup_ac3DynamicRangeType selectItemAtIndex:0];
	else if(newVal == 2.0)
		[popup_ac3DynamicRangeType selectItemAtIndex:1];
	else
		[popup_ac3DynamicRangeType selectItemAtIndex:3];
}

- (void)saveAC3DynamicRange:(float)newVal
{
	[self setKey:AC3DynamicRangeKey forAppID:a52AppID fromFloat:newVal];
	[self setAC3DynamicRange:newVal];
}

- (IBAction)setAC3DynamicRangeValue:(id)sender
{
	float newVal = [textField_ac3DynamicRangeValue floatValue];
	
	[self setAC3DynamicRange:newVal];
}

- (IBAction)setAC3DynamicRangeSlider:(id)sender
{
	float newVal = [slider_ac3DynamicRangeSlider floatValue];
	
	[self setAC3DynamicRange:newVal];
}

- (IBAction)cancelDynRangeSheet:(id)sender
{
	[self setAC3DynamicRange:[self getFloatFromKey:AC3DynamicRangeKey forAppID:a52AppID withDefault:1.0]];
	[NSApp endSheet:window_dynRangeSheet];
	[window_dynRangeSheet orderOut:self];
}

- (IBAction)saveDynRangeSheet:(id)sender;
{
	[NSApp endSheet:window_dynRangeSheet];
	[self saveAC3DynamicRange:nextDynValue];
	[window_dynRangeSheet orderOut:self];
}

#pragma mark About 
- (IBAction)launchWebsite:(id)sender 
{
	[[NSWorkspace sharedWorkspace] openURL:perianWebSiteURL];
} 

- (IBAction)launchDonate:(id)sender 
{
	
	[[NSWorkspace sharedWorkspace] openURL:perianDonateURL];
} 

- (IBAction)launchForum:(id)sender 
{
	
	[[NSWorkspace sharedWorkspace] openURL:perianForumURL];
	
}

@end
