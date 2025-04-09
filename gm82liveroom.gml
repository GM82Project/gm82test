#define __gm82liveroom_init
    globalvar __gm82liveroom_listen;__gm82liveroom_listen=noone
    globalvar __gm82liveroom_sock;__gm82liveroom_sock=noone
    globalvar __gm82liveroom_nochange;__gm82liveroom_nochange=ds_list_create()
    globalvar __gm82liveroom_directory;__gm82liveroom_directory=working_directory


//----------------------live path module----------------------------------------

#define __gm82liveroom_path_reload
    ///liveroom_path_reload()
    //Reloads all paths from disk.
    
    var __dir,__str,__f,__f2,__path;
    __dir=__gm82liveroom_directory+"\paths\"

    __f=file_text_open_read(__dir+"index.yyd")
    do {
        __str=file_text_read_string(__f)
        file_text_readln(__f)
        if (__str!="") {
            __path=execute_string("return "+__str)
            path_clear_points(__path)
            __f2=file_text_open_read(__dir+__str+"\points.txt")
            do {
                string_token_start(file_text_read_string(__f2),",")
                file_text_readln(__f2)
                path_add_point(__path,real(string_token_next()),real(string_token_next()),real(string_token_next()))
            } until file_text_eof(__f2)
            file_text_close(__f2)
        }  
    } until file_text_eof(__f)
    file_text_close(__f)

//----------------------live room editor module---------------------------------

#define liveroom_start
    ///liveroom_start()
    //Initializes the live room editor module. This must be called before attempting to connect with the room editor.
    
    with (gm82core_object) {
        if (__gm82liveroom_listen==noone) {
            object_event_add(gm82core_object,ev_step,ev_step_begin,"__gm82liveroom_poll()")
            object_event_add(gm82core_object,ev_other,ev_room_start,"__gm82liveroom_request()")
            __gm82liveroom_listen=listeningsocket_create()
            listeningsocket_start_listening(__gm82liveroom_listen,0,4126,1)
        }
    }


#define liveroom_status
    ///liveroom_status()
    //returns: A status string with the state of the live connection to the room editor.
    //"offline": no connection is made.
    //"ready": waiting for the room editor.
    //"active": live session in progress.
    
    if (__gm82liveroom_sock!=noone) return "active"
    if (__gm82liveroom_listen!=noone) return "ready"
    return "offline"
    

#define liveroom_add_obj_exclusion
    ///liveroom_add_obj_exclusion(object)
    //object: object index to exclude
    //Adds an object to the exclusion list for live room reloads. These objects aren't destroyed, recreated or otherwise synced.
    
    ds_list_add(__gm82liveroom_nochange,argument0)


#define __gm82liveroom_poll
    if (listeningsocket_can_accept(__gm82liveroom_listen)) {
        //currently if a second connection is made this will leak a buffer and a socket
        __gm82liveroom_sock=socket_create()
        __gm82liveroom_buf=buffer_create()
        listeningsocket_accept(__gm82liveroom_listen,__gm82liveroom_sock)
    }
    var __obj,__i;
    if (__gm82liveroom_sock!=noone) {
        socket_update_read(__gm82liveroom_sock)
        while (socket_read_message(__gm82liveroom_sock,__gm82liveroom_buf)) {
            buffer_set_pos(__gm82liveroom_buf,0)
            type=buffer_read_u8(__gm82liveroom_buf)
            roomname=buffer_read_string(__gm82liveroom_buf)
            if (roomname==room_get_name(room)) {
                //objects
                if (type==1) {
                    repeat (buffer_read_u16(__gm82liveroom_buf)) {
                        __obj=buffer_read_u16(__gm82liveroom_buf)
                        //if it isnt on the exclusion list
                        if (ds_list_find_index(__gm82liveroom_nochange,__obj)==-1) {
                            //clear out all instances of this obj
                            with (__obj) if (object_index==__obj) {
                                //do room end before destroy to prevent memory leaks
                                event_perform(ev_other,ev_room_end)
                                instance_destroy()
                            }
                            repeat (buffer_read_u16(__gm82liveroom_buf)) {
                                __i=instance_create(buffer_read_i32(__gm82liveroom_buf),buffer_read_i32(__gm82liveroom_buf),__obj)
                                if (instance_exists(__i)) {                            
                                    __i.image_xscale=buffer_read_double(__gm82liveroom_buf)
                                    __i.image_yscale=buffer_read_double(__gm82liveroom_buf)
                                    __i.image_angle=buffer_read_double(__gm82liveroom_buf)
                                    __i.image_blend=buffer_read_u32(__gm82liveroom_buf)
                                    __i.image_alpha=buffer_read_double(__gm82liveroom_buf)
                                    with (__i) {
                                        execute_string(buffer_read_string(other.__gm82liveroom_buf))
                                        event_perform(ev_other,ev_room_start)
                                    }
                                } else {
                                    //some instances might destroy themselves on create so we need to skip over its data
                                    buffer_read_double(__gm82liveroom_buf)
                                    buffer_read_double(__gm82liveroom_buf)
                                    buffer_read_double(__gm82liveroom_buf)
                                    buffer_read_u32(__gm82liveroom_buf)
                                    buffer_read_double(__gm82liveroom_buf)
                                    buffer_read_string(__gm82liveroom_buf)
                                }
                            }
                        } else {
                            //this object is excluded, so we skip all instances of it
                            //(the room editor does not have this kind of information)
                            repeat (buffer_read_u16(__gm82liveroom_buf)) {
                                buffer_read_i32(__gm82liveroom_buf)
                                buffer_read_i32(__gm82liveroom_buf)
                                buffer_read_double(__gm82liveroom_buf)
                                buffer_read_double(__gm82liveroom_buf)
                                buffer_read_double(__gm82liveroom_buf)
                                buffer_read_u32(__gm82liveroom_buf)
                                buffer_read_double(__gm82liveroom_buf)
                                buffer_read_string(__gm82liveroom_buf)
                            }
                        }
                    }
                }
                //tiles
                if (type==2) {
                    /*
                    tiles arent implemented at the moment
                    repeat (buffer_read_u32(__gm82liveroom_buf)) {
                        tile_layer_delete(buffer_read_i32(__gm82liveroom_buf))
                    }
                    repeat (buffer_read_u32(__gm82liveroom_buf)) {
                        tile_add
                    }*/
                }
            }
        }
    }


#define __gm82liveroom_request
    if (__gm82liveroom_sock!=noone) {
        buffer_clear(__gm82liveroom_buf)
        buffer_write_u8(__gm82liveroom_buf,1)
        socket_write_message(__gm82liveroom_sock,__gm82liveroom_buf)
        socket_update_write(__gm82liveroom_sock)
    }
//
//