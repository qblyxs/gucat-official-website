import pymysql,os

DOMAINS = ["127.0.0.1", "dev.gucat.vip", "124.221.121.144"]
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': os.path.join('/app/db' , 'db.sqlite3'),
    }
}