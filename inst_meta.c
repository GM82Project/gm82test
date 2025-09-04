/*
 * inst_meta.c
 * Instance reflection for Game Maker 8
 * (c) iwVerve
 */

#define _USE_MATH_DEFINES
#define VC_EXTRALEAN
#define WIN32_LEAN_AND_MEAN

#include <stdio.h>
#include <stdint.h>

#define GMREAL __declspec(dllexport) double __cdecl
#define GMSTR __declspec(dllexport) char* __cdecl

#define VAR_NAME_LIST_PTR 0x68869C
#define VAR_NAME_COUNT_PTR 0x6886A0
#define INST_DATA_PTR 0x8452F8

/*
 * StringList
 */

typedef struct {
    char **items;
    int length;
    int capacity;
} StringList;

void StringList_expand(StringList *list, int capacity) {
    if (capacity <= list->capacity) {
        return;
    }

    list->items = (char **)realloc(list->items, capacity * sizeof(char **));
    list->capacity = capacity;
}

StringList StringList_init() {
    StringList list = (StringList){
        .items = NULL,
        .length = 0,
        .capacity = 0,
    };

    StringList_expand(&list, 8);
    return list;
}

void StringList_deinit(StringList list) {
    free(list.items);
}

void StringList_append(StringList *list, char *string) {
    if (list->length >= list->capacity) {
        StringList_expand(list, 2 * list->capacity);
    }

    list->items[list->length] = string;
    list->length += 1;
}

/*
 * Variable name cache
 */

// Caches ASCII-converted variable names.
StringList name_cache;

// Asserts index < *VAR_NAME_COUNT_PTR
void cache_variable_name(int index) {
    char *names = *(void **)VAR_NAME_LIST_PTR;
    char *name_utf16 = *(void **)(names + 4 * index);
    int name_len = *(int *)(name_utf16 - 4);

    char *name_ascii = (char *)malloc(name_len + 0);
    for (int i = 0; i < name_len; i += 1) {
        name_ascii[i] = name_utf16[2 * i];
    }
    name_ascii[name_len] = 0;

    StringList_append(&name_cache, name_ascii);
}

// Asserts index < *VAR_NAME_COUNT_PTR
void cache_variable_names(int up_to_index) {
    for (int i = name_cache.length; i <= up_to_index; i += 1) {
        cache_variable_name(i);        
    }
}

// index is 0-indexed.
// Returns "" if index is out of bounds.
char *get_variable_name(int index) {
    if (index < 0 || index >= *(int *)VAR_NAME_COUNT_PTR) {
        return "";
    }

    if (index >= name_cache.length) {
        cache_variable_names(index);
    }

    return name_cache.items[index];
}

/*
 * Instance data
 */

// Real if type == 0, string if 1.
typedef struct {
    int name_index;
    char padding_a[4];
    int type;
    char padding_b[4];
    double real_value;
    char *string_value;
    char padding_c[12];
} Variable;

// Must be 384 bytes.
typedef struct {
    char padding_a[4];
    int id;
    char padding_b[252];
    char *vars;
    char padding_c[120];
} Instance;

int get_instance_variable_count(Instance *instance) {
    return *(int *)(instance->vars + 8);
}

Variable *get_instance_variable_list(Instance *instance) {
    return *(Variable **)(instance->vars + 4);
}

int get_instance_count() {
    char *inst_data = *(void **)INST_DATA_PTR;
    return *(int *)(inst_data + 104);
}

// Performs bounds checks.
// Returns NULL on error.
Instance *get_instance_by_index(int index) {
    char *inst_data = *(void **)INST_DATA_PTR;

    int instance_count = *(int *)(inst_data + 104);
    if (index < 0 || index >= instance_count) {
        return NULL;
    }

    Instance **instance_list = *(void **)(inst_data + 108);
    return instance_list[index];
}

// Returns NULL if not found.
Instance *get_instance_by_id(int id) {
    int instance_count = get_instance_count();

    for (int i = 0; i < instance_count; i += 1) {
        Instance *instance = get_instance_by_index(i);
        if (instance == NULL) {
            continue;
        }

        if (instance->id == id) {
            return instance;
        }
    }

    return NULL;
}

/*
 * Iterator
 */

typedef struct {
    Instance *instance;
    Variable *list;
    int length;
    int index;
} Iterator;

Iterator iterator = {};

int iterator_start(int id) {
    iterator.index = 0;

    iterator.instance = get_instance_by_id(id);
    if (iterator.instance == NULL) {
        iterator.length = 0;
        return 0;
    }

    iterator.list = get_instance_variable_list(iterator.instance);
    if (iterator.list == NULL) {
        iterator.length = 0;
        return 0;
    }

    iterator.length = get_instance_variable_count(iterator.instance);
    return iterator.length;
}

char *iterator_next() {
    if (iterator.index >= iterator.length) {
        return "";
    }

    Variable *variable = &iterator.list[iterator.index];
    iterator.index += 1;

    return get_variable_name(variable->name_index - 100000);
}

/*
 * Extension API
 */

GMREAL __gm82_inst_meta_init() {
    name_cache = StringList_init();
    return 0;
}

GMREAL __gm82_inst_meta_final() {
    StringList_deinit(name_cache);
    return 0;
}

GMREAL variable_instance_names_start(double id) {
    return iterator_start(id);
}

GMSTR variable_instance_names_next() {
    return iterator_next();
}
