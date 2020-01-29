component {
	cfprocessingdirective( preserveCase=true );

	function init(
		string apiKey= ""
	,	string apiUrl= "https://ipapi.co"
	,	numeric throttle= 100
	,	string userAgent= "ipapi-cfml-api-client/0.1"
	,	numeric httpTimeOut= 3
	,	boolean debug= ( request.debug ?: false )
	) {
		this.apiUrl= arguments.apiUrl;
		this.apiKey= arguments.apiKey;
		this.userAgent= arguments.userAgent;
		this.throttle= arguments.throttle;
		this.httpTimeOut= arguments.httpTimeOut;
		this.debug= arguments.debug;
		this.lastRequest= server.ipapi_lastRequest ?: 0;
		return this;
	}

	function debugLog( required input ) {
		if ( structKeyExists( request, "log" ) && isCustomFunction( request.log ) ) {
			if ( isSimpleValue( arguments.input ) ) {
				request.log( "ipapi: " & arguments.input );
			} else {
				request.log( "ipapi: (complex type)" );
				request.log( arguments.input );
			}
		} else if( this.debug ) {
			cftrace( text=( isSimpleValue( arguments.input ) ? arguments.input : "" ), var=arguments.input, category="ipapi", type="information" );
		}
		return;
	}

	string function getRemoteIp(){
		if( len( cgi.http_x_cluster_client_ip)  ) {
			return trim( listFirst( cgi.http_x_cluster_client_ip ) );
		}
		if( len( cgi.http_x_forwarded_for ) ) {
			return trim( listFirst( cgi.http_x_forwarded_for ) );
		}
		return cgi.remote_addr;
	}

	struct function ipDetail( string ip= this.getRemoteIp() ) {
		var out= this.apiRequest( "GET /#arguments.ip#/json/" );
		return out;
	}

	struct function quota( string ip= this.getRemoteIp() ) {
		var out= this.apiRequest( "GET /quota/" );
		return out;
	}

	// struct function ipField( required string field, string ip= this.getRemoteIp() ) {
	// 	var out= this.apiRequest( "GET /#arguments.ip#/#arguments.field#/" );
	// 	return out;
	// }

	struct function apiRequest( required string api ) {
		var http= 0;
		var dataKeys= 0;
		var item= "";
		var out= {
			success= false
		,	error= ""
		,	status= ""
		,	json= ""
		,	statusCode= 0
		,	response= ""
		,	verb= listFirst( arguments.api, " " )
		,	requestUrl= this.apiUrl & listRest( arguments.api, " " )
		};
		if ( this.debug ) {
			this.debugLog( out );
		}
		if ( this.throttle > 0 && this.lastRequest > 0 ) {
			out.delay= this.throttle - ( getTickCount() - this.lastRequest );
			if ( out.delay > 0 ) {
				this.debugLog( "Pausing for #out.delay#/ms" );
				sleep( out.delay );
			}
		}
		cftimer( type="debug", label="ipapi.co request" ) {
			cfhttp( result="http", method=out.verb, url=out.requestUrl, throwOnError=false, userAgent=this.userAgent, timeOut=this.httpTimeOut, charset="UTF-8" ) {
				if( len( this.apiKey ) ) {
					cfhttpparam( name="key", type="url", value=this.apiKey );
				}
			}
		}
		if ( this.throttle > 0 ) {
			this.lastRequest= getTickCount();
			server.ipapi_lastRequest= this.lastRequest;
		}
		out.response= toString( http.fileContent );
		// this.debugLog( out.response );
		out.statusCode = http.responseHeader.Status_Code ?: 500;
		this.debugLog( out.statusCode );
		if ( left( out.statusCode, 1 ) == 4 || left( out.statusCode, 1 ) == 5 ) {
			out.success= false;
			out.error= "status code error: #out.statusCode#";
		} else if ( out.response == "Connection Timeout" || out.response == "Connection Failure" ) {
			out.error= out.response;
		} else if ( left( out.statusCode, 1 ) == 2 ) {
			out.success= true;
		}
		// parse response 
		if ( len( out.response ) ) {
			try {
				out.response= deserializeJSON( out.response );
				if ( isStruct( out.response ) && structKeyExists( out.response, "reason" ) ) {
					out.success= false;
					out.error= out.response.reason;
				}
			} catch (any cfcatch) {
				out.error= "JSON Error: " & (cfcatch.message?:"No catch message") & " " & (cfcatch.detail?:"No catch detail");
			}
		}
		if ( len( out.error ) ) {
			out.success= false;
		}
		return out;
	}

}