# Taken from http://www.binarysludge.com/2012/09/05/turbocharging-wordpress/
# This is a basic Varnish 3 VCL configuration file for varnish.  See the vcl(7)
# man page for details on VCL syntax and semantics.
#
# Default backend definition.  Set this to point to your content
# server.
#
backend default {
  .host = "{VARNISH_BACKEND_HOST}";
  .port = "{VARNISH_BACKEND_PORT}";
  .connect_timeout = 600s;
  .first_byte_timeout = 600s;
  .between_bytes_timeout = 600s;
  .max_connections = 2000;
}
 
 
sub vcl_recv {
    set req.http.X-Forwarded-For = client.ip;
 
 
    if (req.http.host != "VARNISH_BACKEND_DOMAIN") {
      return(pass);
    }
 
    #never cache POST requests
    if (req.request == "POST")
    {
      return(pass);
    }
 
    ### do not cache these files:
    ## never cache the admin pages, or the server-status page
    if (req.request == "GET" && req.url ~ "(wp-admin|bb-admin|server-status|feed)")
    {
      return(pass);
    }
 
    if (req.request == "GET" && req.url ~ "\.(css|js|gif|jpg|jpeg|bmp|png|ico|img|tga|wmf)$") {
      remove req.http.cookie;
      return(lookup);
    }
    if (req.request == "GET" && req.url ~ "(xmlrpc.php|wlmanifest.xml)") {
      remove req.http.cookie;
      return(lookup);
    }
 
    # DO cache this ajax request
    if(req.http.X-Requested-With == "XMLHttpRequest" && req.url ~ "recent_reviews")
    {
      return (lookup);
    }
 
    # dont cache ajax requests
    if(req.http.X-Requested-With == "XMLHttpRequest" || req.url ~ "nocache" || req.url ~ "(control.php|wp-comments-post.php|wp-login.php|bb-login.php|bb-reset-password.php|register.php)")
    {
        return (pass);
    }
 
    if (req.http.Cookie && req.http.Cookie ~ "wordpress_") {
        set req.http.Cookie = regsuball(req.http.Cookie, "wordpress_test_cookie=", "; wpjunk=");
    }
	
    ### don't cache authenticated sessions
    if (req.http.Cookie && req.http.Cookie ~ "(wordpress_|PHPSESSID)") {
        return(pass);
    }
 
    ### parse accept encoding rulesets to make it look nice
    if (req.http.Accept-Encoding) {
        if (req.http.Accept-Encoding ~ "gzip") {
            set req.http.Accept-Encoding = "gzip";
        } elsif (req.http.Accept-Encoding ~ "deflate") {
			set req.http.Accept-Encoding = "deflate";
        } else {
			# unkown algorithm
			remove req.http.Accept-Encoding;
        }
    }
 
    if (req.http.Cookie)
    {
        set req.http.Cookie = regsuball(req.http.Cookie, "; +", ";");
        set req.http.Cookie = regsuball(req.http.Cookie, ";(vendor_region|PHPSESSID|themetype2|w3tc_referrer)=", "; \1=");
        set req.http.Cookie = regsuball(req.http.Cookie, ";[^ ][^;]*", "");
        set req.http.Cookie = regsuball(req.http.Cookie, "^[; ]+|[; ]+$", "");
 
        if (req.http.Cookie == "") {
			remove req.http.Cookie;
        }
    }
 
    return(lookup);
}
 
 
 
sub vcl_fetch {
    if (beresp.ttl > 0s) {
        /* Remove Expires from backend, it's not long enough */
        unset beresp.http.expires;
 
        /* Set the clients TTL on this object */
        set beresp.http.cache-control = "max-age=900";
 
        /* Set how long Varnish will keep it */
        set beresp.ttl = 1w;
 
        /* marker for vcl_deliver to reset Age: */
        set beresp.http.magicmarker = "1";
    }
}
 
sub vcl_deliver {
    if (resp.http.magicmarker) {
        /* Remove the magic marker */
        unset resp.http.magicmarker;
 
        /* By definition we have a fresh object */
        set resp.http.age = "0";
    }
}
