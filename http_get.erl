%=================================================================================

-module(http_get).
-compile(export_all).
-include("http_get.hrl").

%-compile(native).
%-compile(inline).
% -compile({inline_size,1000}).
% -compile({inline_effort,2000}).
% -compile({inline_unroll,6}).

%=================================================================================

main([URL])->
	send_request( list_to_binary(URL) , 0 );
main(_)->
	io:format(bye).

%=================================================================================

send_request( <<"https://",_/binary>> = UB , _ )->
	os:cmd(?CURLGET(UB) ) ;
send_request(UB , 0 )->
	[ _ , TB ] 	= binary:split(UB, <<"http://">>) ,
	[ HB | _ ] 	= binary:split( TB , <<"/">>),
	send_request(UB , HB );
send_request(UB , HB )->
	case gen_tcp:connect( btos(HB) , 80 , ?TCP_CONN_OPTS , 10000 ) of
		{ ok , Sock }->
			do_send_request(Sock , UB , HB ) ;
		Err->
			?PRN( {HB,Err} )
	end.

%=================================================================================

do_send_request( Sock , <<"http://", More_bin/binary>>  , Host )->
	case binary:split(More_bin , <<"/">>) of
		[_ , P0]->
			Path = ["/" , P0] ;
		[_ ]->
			Path = "/"
	end ,
	Request 	= ?REQUEST11(Path,Host) ,
	ok		=gen_tcp:send( Sock , Request ),
	Rep_bin	= receive_reply( Sock , <<>> ) ,
	case re:run(Rep_bin , "\r\nLocation ?: ?(https?://([^/\r\n]*).*)\r\n" , ?REGEX_CAP_ALL ) of
		{ match , [ _ , Loc , Host ]} ->
			do_send_request( Sock , Loc , Host ) ;
		{ match , [ _ , Loc , Host_new ]} ->
			gen_tcp:close(Sock),
			send_request( Loc , Host_new );
		nomatch->
			gen_tcp:close(Sock) ,
			process_reply(Rep_bin)
	end .

%=================================================================================

receive_reply(S , Acc_bin )->
	receive
		{ tcp , S , BB}->
			Rep_bin = iolist_to_binary([Acc_bin,BB]) ,
			case is_reply_complete(Rep_bin) of
				true->
					Rep_bin;
				_->
					receive_reply(S , Rep_bin ) 
			end;
		_->
			Acc_bin
	end.

%=================================================================================

is_reply_complete(Rep_bin)->
	case re:run(Rep_bin , "\r\ncontent-length ?: ?([0-9]+)\r\n" , ?REGEX_CAP_ALL ) of
		nomatch->
			(match == re:run(Rep_bin , "\r\ntransfer-encoding ?: ?.*chunked.*\r\n" , ?REGEX_CAP_NONE )) 
			and 
			( match == re:run( Rep_bin , "\r\n0+\r\n\r\n$" , ?REGEX_CAP_NONE ) ) ;
		{match,[_,CLB]}->
			Cont_len = binary_to_integer( CLB ) ,
			case binary:split(Rep_bin , <<"\r\n\r\n">> ) of
				[_HDRS , Body]->
					size(Body)==Cont_len;
				_->
					false
			end
	end.

%=================================================================================

dechunkify(<<>>)->
	[];
dechunkify(BB) when is_binary(BB)->
	[ Len_bin , Temp_bin ] = binary:split(BB , <<"\r\n">>) ,
	Len =  binary_to_integer(Len_bin,16) ,
	<< Chunk:Len/binary , "\r\n" , BB_new/binary>> = Temp_bin ,
	[ Chunk | dechunkify(BB_new)  ] ;
dechunkify([BB])->
	dechunkify(BB).

%=================================================================================

btos(Bin)->
	binary_to_list(Bin).

%=================================================================================

process_reply(Rep_bin)->
	[Hdrs | Maybe_chnked] = binary:split(Rep_bin, ?CRLFCRLF ) ,

	Maybe_gz=
		case re:run(Hdrs , "\r\ntransfer-encoding ?: ?.*chunked.*\r\n" , ?REGEX_CAP_NONE ) of
			match->
				dechunkify(Maybe_chnked) ;
			_->
				Maybe_chnked
		end,

	try zlib:gunzip(Maybe_gz) of
		Body->
			io:format(Body)
	catch
		error:data_error->
			io:format(Maybe_gz)
	end.

%=================================================================================
% 
% redirect(Rep_bin , HB , Sock)->
% 	case re:run(Rep_bin , "\r\nLocation ?: ?(https?://([^/\r\n]*).*)\r\n" , ?REGEX_CAP_ALL ) of
% 		{match,[_ , UB1 , HB ]} ->
% 			send_request( Sock , UB1 , HB ) ;
% 		{match,[_ , UB1 , _HB1 ]} ->
% 			gen_tcp:close(Sock),
% 			connect_to_host(UB1);
% 		nomatch->
% 			gen_tcp:close(Sock)
% 	end .
% 
%=================================================================================
% 
% send_request( Sock , <<"http://", More_bin/binary>>  , HB )->
% 	case binary:split(More_bin , <<"/">>) of
% 		[_ , P0]->
% 			Path_bin = <<"/" , P0/binary>>;
% 		[_ ]->
% 			Path_bin = <<"/">>
% 	end ,
% 	Req_bin = iolist_to_binary( ?REQUEST11(Path_bin,HB) ) ,
% 	gen_tcp:send( Sock , Req_bin ),
% 	Rep_bin	= receive_reply( Sock , <<>> ) ,
% 	case re:run( Rep_bin , "HTTP/(1\.1|1\.0|0\.9) 200 " , ?REGEX_CAP_NONE ) of
% 		match->
% 			gen_tcp:close(Sock) ,
% 			process_reply(Rep_bin) ;
% 		nomatch->
% 			redirect(Rep_bin , HB , Sock)
% 	end ;
% send_request(S,_Url_bin,_HB)->
% 	gen_tcp:close(S) .
% 	%os:cmd( ?CURLGET(Url_bin,HB)).
% 
%=================================================================================
%=================================================================================
%=================================================================================
