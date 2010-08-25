#ifndef COMMON_H_
#define COMMON_H_

// Filename macro
#ifndef __FILENAME__
  #define __FILENAME__ ((strrchr(__FILE__, '/') ?: __FILE__ - 1) + 1)
#endif
#define __SRC_FILENAME__ \
	((common_strrstr(__FILE__, "/src/") ?: __FILE__ - 1) + 1)

// Debug/development utilities
#if !defined(_DEBUG) && defined(DEBUG)
#define _DEBUG DEBUG
#endif
	
#if _DEBUG
	// shorthand to include and evaluate <x> only for debug builds
	#define IFDEBUG(x) x
	#ifdef __OBJC__
		// logd(format[, ...]) -- log a debug message
		#define logd(fmt, ...) NSLog(@"D [%s:%d] " fmt, __SRC_FILENAME__, \
																 __LINE__, ##__VA_ARGS__)
		// logmark -- log a "mark"
		#define logmark				 NSLog(@"M [%s:%d] %s", __SRC_FILENAME__, __LINE__, \
																 __PRETTY_FUNCTION__)
	#else
		// logd(format[, ...]) -- log a debug message
		#define logd(fmt, ...) fprintf(stderr, "%s [%d] D [%s:%d] " fmt "\n", \
																	 __FILENAME__, getpid(), __SRC_FILENAME__, \
																	 __LINE__, ##__VA_ARGS__)
		// logmark -- log a "mark"
		#define logmark	 fprintf(stderr, "%s [%d] M [%s:%d] %s\n", __FILENAME__, \
														 getpid(), __SRC_FILENAME__, __LINE__, \
														 __PRETTY_FUNCTION__)
	#endif
	// log an expression
	#ifdef __OBJC__
		#define loge(_X_) do{\
			__typeof__(_X_) _Y_ = (_X_);\
			const char * _TYPE_CODE_ = @encode(__typeof__(_X_));\
			NSString *_STR_ = VTPG_DDToStringFromTypeAndValue(_TYPE_CODE_, &_Y_);\
			if(_STR_){\
				NSLog(@"X [%s:%d] %s = %@", __SRC_FILENAME__, __LINE__, #_X_, _STR_);\
			}else{\
				NSLog(@"Unknown _TYPE_CODE_: %s for expression %s in function %s, file %s, line %d",\
				      _TYPE_CODE_, #_X_, __func__, __SRC_FILENAME__, __LINE__);\
			}}while(0)
	#else // __OBJC__
		#define loge(_X_) fprintf(stderr, "%s [%d] X [%s:%d] %s = %s\n",\
															__FILENAME__, getpid(), __SRC_FILENAME__, __LINE__, \
															#_X_, "<TODO:common.h>")
		// TODO eval expression ---------------^
	#endif // __OBJC__
#else // _DEBUG
	#define IFDEBUG(x)
	#define logd(...)
	#define logmark
	#define loge(...)
#endif // _DEBUG

const char *common_strrstr(const char *string, const char *find);

#ifdef __OBJC__
#import <Foundation/Foundation.h>
NSString *VTPG_DDToStringFromTypeAndValue(const char *typeCode, void *value);
static inline BOOL IsEmpty(id thing) {
	return thing == nil ||
  ([thing respondsToSelector:@selector(length)] && [(NSData *)thing length] == 0) ||
  ([thing respondsToSelector:@selector(count)]  && [(NSArray *)thing count] == 0);
}
#endif // __OBJC__

#endif // COMMON_H_
