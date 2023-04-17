# My Environment

	0.	Install Ansible
	0.	https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#from-pip
	0.	Install using Python’s PIP package manager.
	0.	Use —user rather than sudo. By default, PIP installs python packages to a system directory requiring root access. However these are global changes that could leave your Mac in an inconsistent state. So use —user instead (which installs the packages to your home directory instead)
	0.	You don’t have to worry about using —user when in a virtual environment (since they’re already installed in a virtualenv folder and isolated.
	0.	Virtualenv
	0.	pip3 install -U --user virtualenv
	0.	Usage: https://medium.com/swlh/how-to-setup-your-python-projects-1eb5108086b1
	0.	Update PATH (export PATH=$PATH:xxxx) with new location where the virtualenv package is installed.



# Steps to setup the app:
	⁃	Install Virtualenv
	⁃	Update PATH
	⁃	Create project directory
	⁃	Create venv and activate it
	⁃	Create app:
	⁃	Quick Tutorial: https://dhsashini.medium.com/building-a-python-flask-application-f051fffa0bfa
	⁃	More Deets: https://www.freecodecamp.org/news/how-to-build-a-web-application-using-flask-and-deploy-it-to-the-cloud-3551c985e492/
	⁃	Pipe freeze
	⁃	Deactivate the environment
	⁃	Containerize it
	⁃	https://www.docker.com/blog/containerized-python-development-part-1/
	⁃	https://stackoverflow.com/questions/30323224/deploying-a-minimal-flask-app-in-docker-server-connection-issues
	⁃	Using NGINX: https://stackabuse.com/dockerizing-python-applications/  
	⁃	Create AWS Infrastructure
	⁃	Run Playbook on Controller
	⁃	Runs Flask container
	⁃	When the infrastructure comes up:
	⁃	The targets must be registered and healthy. Otherwise you’ll get a 503 Bad Gateway error when hitting the ALB.
	⁃	The security group must be open between ALB <—> Targets to allow the health check to happen. The application must also be running (do netstat to see if targets are listening on their health check ports). If neither of these are in place, you’ll get a 502 error.
	⁃	Buy a Domain.
	⁃	After running TF (which creates the Hosted Zone and Alias records), update GoDaddy with the zone’s AWS-provided Nameserver’s.
	⁃	SSL
	⁃	Termination at LB is simplest and secures communication between server/client.
	⁃	For maximum end-to-end security, you could terminate HTTPS at the LB, re-encrypt and pass on to the instances, and re-terminate at the instance. Or you can just terminate at the instances only (this removes the ability of the LB to see the traffic content and do smart routing).
	⁃	https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/configuring-https.html


# Serving the App to the Public:
	⁃	We’ve built our app and setup our infrastructure. But we also need a Webserver.
	⁃	Our application needs to be published aka “served” to be accessible to external requests.
	⁃	Flask comes with a built-in Webserver (Werkzeug's WSGI server). It exposes the app on your local machine and is only really meant for development. It is doesn’t scale well, only handles one request at a time (works on one thread only), isn’t secure, and serves static files veryyyy slowly. In PROD, we need all the opposite.
	⁃	Instead, use a real WSGI appserver (like uWSGI or Gunicorn). This gives you performance since it can handle many requests.
	⁃	Since uWSGI/Gunicorn aren’t designed as webservers…proxy them through a real webserver like NGINX for performance/security. It will handle SSL, serve static content well and can queue requests. Webservers also run as root - meaning they can listen on port 80/443 so your customers don’t need to know your port. Your app should NEVER run as root (which means it can only listen on ports above 1024).
	⁃	In PROD, we tend to use multiple tools, each designed to be really good at one thing.
	⁃	So in PROD:
	⁃	We’d use a Webserver. HTTP requests for our app hit this server.
	⁃	If the request is for static content, the Webserver handles this alone.
	⁃	If the request is meant for our app, the Webserver will then hands off this request down to a dedicated app server.
	⁃	The app server calls our Flask app, passing it the HTTP request as a Python request object, which is usable by the Flask framework (the WSGI spec/convention dictates how webservers should forward requests to Python webapps).
	⁃	The flask app runs and returns a response to the App server, which passes that back.
	⁃	So our Flask app isn’t really a server. It’s more of a function being invoked by our actually Application Server.
	⁃	Gunicorn Notes:
	⁃	Gunicorn and other WSGI servers, default to looking for a callable named “application”. So in your WSGI file, import your python project but alias it as “application”: https://stackoverflow.com/questions/33379287/gunicorn-cant-find-app-when-name-changed-from-application/33379650
	⁃	Once running as a SystemD service, you can curl by hitting the socket: curl --unix-socket /home/ec2-user/lamp-stack-v1/flask-app/src/app.sock g
	⁃	Now the app server is listening for requests to hit the socket.
	⁃	You can either run Gunicorn on a network port, or bind it to a socket. Sockets are faster but don’t work over a network (i.e if your webserver and app are on different machines). So if they’re on the same machine, use a socket (also saves you from opening another port thus having a more hardened machine). If different machines, use a port: https://stackoverflow.com/questions/19916016/gunicorn-nginx-server-via-socket-or-proxy
	⁃	Processes are unable to communicate with eacother by default. They do so via sockets (which are basically communication tunnels). Unix sockets are for processes on a same machine to talk. Internet sockets are for processes on different machines to talk: https://medium.com/swlh/getting-started-with-unix-domain-sockets-4472c0db4eb1  
	⁃	NGINX
	⁃	502 Bad Gateway Troubleshooting: https://www.datadoghq.com/blog/nginx-502-bad-gateway-errors-gunicorn/
	⁃	Set SELinux to permissive (/etc/selinux/config) and reboot the machine.
	⁃	Via Containers
	⁃	Dockerized Flask App interfaced by a Gunicorn app server.
	⁃	Flask & Gunicorn are one process since the latter runs the former (NGINX is a separate process, so it should be a separate container).
	⁃	For the NGINX container, the key modification is the nginx.conf file.
	⁃	NGINX handles HTTP requests and reverse proxies them to the upstream Gunicorn server (it can also do load balancing to many upstreams).
	⁃	NGINX can’t interface with a Flask app which is where a WSGI-compliant server like Gunicorn comes into play.
	⁃	https://itnext.io/how-to-deploy-gunicorn-behind-nginx-in-a-shared-instance-f336d2ba4519
	⁃	Some deets: https://kmmanoj.medium.com/deploying-a-scalable-flask-app-using-gunicorn-and-nginx-in-docker-part-1-3344f13c9649
	⁃	Some more deets: https://medium.com/@greut/minimal-python-deployment-on-docker-with-uwsgi-bc5aa89b3d35
	⁃	Resources: https://www.reddit.com/r/docker/comments/8heb95/deploying_flask_app_with_nginx_and_gunicorn/
	⁃	Super Deets:
	⁃	NGINX config: https://www.patricksoftwareblog.com/how-to-configure-nginx-for-a-flask-web-application/
	⁃	http://www.patricksoftwareblog.com/how-to-use-docker-and-docker-compose-to-create-a-flask-application/
	⁃	Cert
	⁃	Create self-signed cert.
	⁃	Upload it to the LB.
	⁃	Add an HTTPS Listener rule to the LB
	⁃

src: https://www.reddit.com/r/aws/comments/j1f6uj/does_alb_remove_the_need_to_put_a_nginx_server_in/
	⁃	If you use an ALB, you remove the NEED for NGINX, but not the DESIRE.
	⁃	WIth NGINX, you can throttle requests so that they don’t bottleneck your app. You can also send traffic to different locations depending if it’s requesting static/dynamic content, etc.
	⁃	So an ALB can hand of requests to NGINX and move on to handling new requests, rather than getting tied down. NGINX has the ability to queue up extra requests.
	⁃	From a performance perspective, it’s better to have NGINX on the app server (or in the same container or asa sidecar), rather than on a separate server/container.



# Sources:
	⁃	Why use Web/App servers:
	⁃	https://devops.stackexchange.com/questions/9218/whats-the-benefit-of-using-nginx-to-serve-a-flask-api-on-aws
	⁃	https://vsupalov.com/flask-web-server-in-production/
	⁃	https://stackoverflow.com/questions/33086555/why-shouldnt-flask-be-deployed-with-the-built-in-server
	⁃	NGINX basics:
	⁃	http://nginx.org/en/docs/beginners_guide.html#static
	⁃	https://medium.com/@jgefroh/a-guide-to-using-nginx-for-static-websites-d96a9d034940
	⁃	WSGI 101:
	⁃	https://www.digitalocean.com/community/tutorials/how-to-set-up-uwsgi-and-nginx-to-serve-python-apps-on-ubuntu-14-04#definitions-and-concepts
	⁃	Launch app with Gunicorn and use NGINX as a Front-End Web Proxy (on Centos7):
	⁃	https://www.digitalocean.com/community/tutorials/how-to-serve-flask-applications-with-gunicorn-and-nginx-on-centos-7



# Useful Diagrams:
	⁃	(And why K8s is better) https://itnext.io/how-to-deploy-gunicorn-behind-nginx-in-a-shared-instance-f336d2ba4519
	⁃	https://www.patricksoftwareblog.com/how-to-configure-nginx-for-a-flask-web-application/
	⁃



# Next Steps:
	⁃	My requirements should now include Gunicorn.
	⁃	Update the Dockerfile’s entrapping to run the Gunicorn command, rather than “flask run”.
	⁃	Bind to 0.0.0.0:80??? Or a socket?? Should be 0.0.0.0:5000
	⁃	https://github.com/dimmg/flusk
	⁃	https://stacko0verflow.com/questions/41789585/serving-flask-via-nginx-and-gunicorn-in-docker
	⁃	When running the container, which host port to map to?
	⁃	Since the app is running in a container, a Virtual Env isn’t needed since either way, it doesn’t touch system python.
	⁃	Separate nginx/frontend container.
	⁃	Map to host port 80
	⁃	Map the local nginx.conf to the container’s.
	⁃	In the conf, set the proxy_pass (in the location context) to the name of the Flask container (as opposed to the local unix socket when we weren’t using containers) - this requires a user-bridged network.
	⁃	Need to incorporate SSL.




***Deploy Dockerized Flask App with NGINX and Gunicorn***
