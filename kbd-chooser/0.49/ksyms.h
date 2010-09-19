#ifndef KSYMS_H
#define KSYMS_H

typedef struct {
	unsigned short uni;
	const char *name;
} sym;

typedef struct {
	const char **table;
	int size;
} syms_entry;

extern syms_entry syms[];

struct syn {
	const char *synonym;
	const char *official_name;
};
extern struct syn synonyms[];

extern const int syms_size;
extern const int syn_size;

extern int set_charset(const char *name);
extern const char *unicodetoksym(int code);
extern int ksymtocode(const char *s);
extern int unicodetocode(int code);
extern int add_capslock(int code);

#endif