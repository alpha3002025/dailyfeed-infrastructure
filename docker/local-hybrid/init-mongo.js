db = db.getSiblingDB('dailyfeed');

db.createUser({
  user: 'dailyfeed-search',
  pwd: 'hitEnter!!!',
  roles: [
    {
      role: 'readWrite',
      db: 'dailyfeed'
    }
  ]
});

// 추가 사용자가 필요한 경우
db.createUser({
  user: 'dailyfeed-svc',
  pwd: 'hitEnter!!!',
  roles: [
    {
      role: 'read',
      db: 'dailyfeed'
    }
  ]
});