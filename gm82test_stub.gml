#define __gm82test_init
    globalvar gm82test_version;gm82test_version=060


#define assert
    repeat (1) {
        if (is_string(argument[0])!=is_string(argument[1])) break
        if (argument[0]!=argument[1]) break
        return 1
    }
    
    var __err;__err="ASSERT: "+string(argument[0])+pick(is_string(argument[0])," (real)"," (string)")+" != "+string(argument[1])+pick(is_string(argument[1])," (real)"," (string)")
    if (argument_count==3) __err+=" - "+string(argument[2])
    
    show_debug_message(__err)
    
    return 0


#define trycatch
    var __ret,__err;
    __err=error_is_enabled()
    if (__err) error_set_enabled(false)
    error_last=""
    if (is_string(argument0)) execute_string(argument0) else script_execute(argument0)
    __ret=error_occurred
    error_occurred=false
    if (__err) error_set_enabled(true)
    return __ret
//
//