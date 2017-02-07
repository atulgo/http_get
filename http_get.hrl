%=================================================================================

-define( PRN(X) 			, io:format("~p :: ~p ::PID = ~p :: ~p\n" , [ ?MODULE_STRING , ?LINE , self() , X]) ).
-define( TCP_CONN_OPTS	, [{packet,0}, binary ] ).
-define( REGEX_CAP_NONE	, [caseless, {newline,crlf} , {capture,none} ] ).
-define( REGEX_CAP_ALL	, [caseless, {newline,crlf} , {capture,all,binary} ] ).
-define( CURLGET(UB)		, ["curl  --raw --include --silent  --header 'Accept-Encoding: gzip' " , binary_to_list(UB) ] ).
-define( CRLFCRLF			, <<"\r\n\r\n">> ).
-define( DEFAULT_URL		, "http://example.com/").
-define( REQUEST11(URL,HB), [
							"GET ",URL," HTTP/1.1\r\n"
							,"Host:",HB,"\r\n"
							, "Accept-Encoding: gzip, deflate, sdch\r\n"
							,"\r\n" 
						] ).

%=================================================================================
