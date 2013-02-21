
# set JAVA_HOME
export JAVA_HOME=`/System/Library/Frameworks/JavaVM.framework/Versions/Current/Commands/java_home`

# set your AWS credentials 
export AWS_ACCESS_KEY=AKIAIHVNPCOHDOHX2NUQ
export AWS_SECRET_KEY=ljeZio9cK+x7RfyrQvcusQpyC46vpErOIbuj3zjP

############################################
# no changes are needed below this line
############################################

# set EC2_HOME and add $EC2_HOME/bin to $PATH
export EC2_HOME=./external_tools/ec2-api-tools-1.6.1.4
export PATH=$PATH:$EC2_HOME/bin

