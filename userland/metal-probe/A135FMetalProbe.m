/*
 * A135F Metal probe: discover whether CoreAnimation can load a device plugin on Mali.
 * Diagnostic stub only: logs MTLDevice calls and returns zero values; it does not render.
 * Enable only with a135f_metal_probe=1.
 */
typedef unsigned long size_t;
void *calloc(size_t, size_t);
void free(void *);
int fprintf(void *, const char *, ...) __attribute__((format(printf, 2, 3)));
const char *getprogname(void);
extern void *__stderrp;
#define stderr __stderrp
#define NULL ((void *)0)
struct objc_method_description { SEL name; const char *types; };
typedef void (*IMP_t)(void);
extern id objc_msgSend(id, SEL, ...);
struct objc_super { id receiver; Class super_class; };
extern id objc_msgSendSuper(struct objc_super *, SEL, ...);
extern Class objc_getClass(const char *);
extern void *objc_getProtocol(const char *);
extern struct objc_method_description *protocol_copyMethodDescriptionList(void *, int, int, unsigned int *);
extern void **protocol_copyProtocolList(void *, unsigned int *);
extern const char *protocol_getName(void *);
extern int class_addMethod(Class, SEL, IMP_t, const char *);
extern int class_addProtocol(Class, void *);
extern Class class_getSuperclass(Class);
extern const char *sel_getName(SEL);
extern SEL sel_registerName(const char *);
extern void _objc_msgForward(void);
extern int strcmp(const char *, const char *);
extern int strncmp(const char *, const char *, size_t);
__attribute__((objc_root_class))
@interface NSObject
@end
@interface _MTLDevice : NSObject
- (id)init;
@end
@interface A135FMetalProbeDevice : _MTLDevice
- (id)initWithAcceleratorPort:(unsigned int)port;
@end
static unsigned int call_count;
#define MLOG(fmt, ...) fprintf(stderr, "A135F Metal probe: " fmt "\n", ##__VA_ARGS__)
static int base_method(const char *n) {
	return strncmp(n, "init", 4) == 0 || strcmp(n, "dealloc") == 0 ||
	       strcmp(n, "retain") == 0 || strcmp(n, "release") == 0 ||
	       strcmp(n, "autorelease") == 0 || strcmp(n, "retainCount") == 0 ||
	       strcmp(n, "class") == 0 || strcmp(n, "respondsToSelector:") == 0;
}
static void route_protocol(Class cls, void *p, int depth) {
	unsigned int n=0;
	for(int req=1;req>=0;req--) {
		struct objc_method_description *m=protocol_copyMethodDescriptionList(p,req,1,&n);
		for(unsigned int i=0;m&&i<n;i++) if(!base_method(sel_getName(m[i].name)))
			(void)class_addMethod(cls,m[i].name,(IMP_t)_objc_msgForward,m[i].types);
		free(m);
	}
	if(depth<4) {
		unsigned int nsub=0; void **sub=protocol_copyProtocolList(p,&nsub);
		for(unsigned int i=0;sub&&i<nsub;i++) {
			const char *name=protocol_getName(sub[i]);
			if(name && !(name[0]=='N'&&name[1]=='S')) route_protocol(cls,sub[i],depth+1);
		}
		free(sub);
	}
}
@implementation A135FMetalProbeDevice
+ (void)load {
	void *spi=objc_getProtocol("MTLDeviceSPI"), *pub=objc_getProtocol("MTLDevice");
	Class cls=objc_getClass("A135FMetalProbeDevice");
	if(spi){(void)class_addProtocol(cls,spi);route_protocol(cls,spi,0);}
	if(pub){(void)class_addProtocol(cls,pub);route_protocol(cls,pub,0);}
	MLOG("bundle loaded; MTLDeviceSPI=%s MTLDevice=%s",spi?"present":"missing",pub?"present":"missing");
}
- (id)initWithAcceleratorPort:(unsigned int)port {
	const char *process = getprogname();
	if (process == NULL || strcmp(process, "backboardd") != 0) {
		MLOG("ignoring Metal device request from %s", process != NULL ? process : "(unknown)");
		return (id)0;
	}
	MLOG("initWithAcceleratorPort: %u",port);
	return [super init];
}
- (id)name {
	static id value;
	if(!value) {
		Class string=objc_getClass("NSString");
		value=((id(*)(Class,SEL,const char*))objc_msgSend)(string,sel_registerName("stringWithUTF8String:"),"A135F Mali-G52 (probe only)");
		value=((id(*)(id,SEL))objc_msgSend)(value,sel_registerName("retain"));
	}
	MLOG("device name queried"); return value;
}
- (signed char)supportsFamily:(long)family {
	signed char yes=family>=1001&&family<=1004;
	MLOG("supportsFamily:%ld -> %s",family,yes?"YES":"NO"); return yes;
}
- (unsigned long)gpuCoreCount { MLOG("gpuCoreCount -> 1"); return 1; }
- (void)forwardInvocation:(id)inv {
	SEL s=((SEL(*)(id,SEL))objc_msgSend)(inv,sel_registerName("selector"));
	id sig=((id(*)(id,SEL))objc_msgSend)(inv,sel_registerName("methodSignature"));
	unsigned long len=((unsigned long(*)(id,SEL))objc_msgSend)(sig,sel_registerName("methodReturnLength"));
	const char *type=((const char*(*)(id,SEL))objc_msgSend)(sig,sel_registerName("methodReturnType"));
	if(call_count++<2000) MLOG("%s return=%s bytes=%lu (probe returns zero)",sel_getName(s),type?type:"?",len);
	if(len){void *zero=calloc(1,len);((void(*)(id,SEL,void*))objc_msgSend)(inv,sel_registerName("setReturnValue:"),zero);free(zero);}
}
- (id)methodSignatureForSelector:(SEL)s {
	struct objc_super sup={self,class_getSuperclass(objc_getClass("A135FMetalProbeDevice"))};
	id sig=((id(*)(struct objc_super*,SEL,SEL))objc_msgSendSuper)(&sup,sel_registerName("methodSignatureForSelector:"),s);
	if(!sig) sig=((id(*)(Class,SEL,const char*))objc_msgSend)(objc_getClass("NSMethodSignature"),sel_registerName("signatureWithObjCTypes:"),"@@:");
	return sig;
}
- (id)doesNotRecognizeSelector:(SEL)s { if(call_count++<2000) MLOG("%s not implemented; returning zero",sel_getName(s)); return (id)0; }
@end
