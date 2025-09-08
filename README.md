# MySQL Replication & Backup Mini Project

## 0. 팀원 소개
| 박여명 | 신준수 |
|:------:|:------:|
| <img src="https://avatars.githubusercontent.com/u/166470537?v=4" alt="박여명" width="150"> | <img src="https://avatars.githubusercontent.com/u/137847336?v=4" alt="신준수" width="150"> |
| [GitHub](https://github.com/yeomyeoung) | [GitHub](https://github.com/shinjunsuuu) |

---

## 1. 프로젝트 개요
이 프로젝트는 **MySQL Replication** 환경을 구축하고, Replica 서버에서 **주기적으로 백업을 자동화**하는 과정을 다룹니다.  
Primary 서버에서 발생한 변경사항을 실시간으로 Replica에 반영하고, Replica 서버에서는 `mysqldump`와 `crontab`을 활용해 **백업 스케줄링**을 구현합니다.

---

## 2. MySQL 사용 이유
- 오픈소스 관계형 DBMS 중 가장 널리 쓰이며, 복제(replication) 기능이 안정적임  
- GTID(Global Transaction ID)를 통한 복제 관리가 쉬움  
- 다양한 백업 도구(mysqldump, Percona XtraBackup) 지원  
- 실습 환경에서 빠르게 구축 가능  

---

## 3. 주요 기능
- **Master–Replica 복제**
  - GTID 기반 설정 (`MASTER_AUTO_POSITION=1`)
  - Primary(x.x.x.x) ↔ Replica(x.x.x.x) 실시간 데이터 반영
- **주기적 백업**
  - Replica 서버에서 `mysqldump` 실행 후 `.tar.gz` 로 압축
  - 파일명에 타임스탬프(`YYYYMMDD_HHMMSS`) 부여
  - 오래된 백업 자동 삭제 (7일 보관 정책)
- **자동화**
  - `cron` 으로 매일 새벽 3시에 백업 실행
  - 로그(`/var/log/mysql_backup.log`)로 결과 확인 가능  

---

## 4. 구성 파일

### 4.1 MySQL 설정 파일
**Primary (`/etc/mysql/mysql.conf.d/mysqld.cnf`)**
```ini
[mysqld]
server-id = 1
log_bin = /var/log/mysql/mysql-bin.log
binlog_format = ROW
gtid_mode = ON
enforce_gtid_consistency = ON
```

**Replica (`/etc/mysql/mysql.conf.d/mysqld.cnf`)**
```ini
[mysqld]
server-id = 2
relay-log = /var/log/mysql/mysql-relay.log
read_only = ON
super_read_only = ON
gtid_mode = ON
enforce_gtid_consistency = ON
```

### 4.2 백업 스크립트 (`/usr/local/bin/mysqldump_backup.sh`)
```bash
#!/usr/bin/env bash
set -euo pipefail

DB_NAME=""
DB_USER=""
DB_PASS=""
BACKUP_DIR="/var/backups/mysql"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

DUMP_FILE="/root/db.sql"
mysqldump -u"$DB_USER" -p"$DB_PASS" --single-transaction --set-gtid-purged=OFF "$DB_NAME" > "$DUMP_FILE"

TAR_FILE="${BACKUP_DIR}/${DB_NAME}_${DATE}.tar.gz"
tar -czf "$TAR_FILE" -C /root db.sql
rm -f "$DUMP_FILE"

find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +7 -delete

echo "[OK] Backup completed: $TAR_FILE"
```

### 4.3 크론탭 설정
```cron
0 3 * * * /usr/local/bin/mysqldump_backup.sh >> /var/log/mysql_backup.log 2>&1
```

---

## 5. 실행 방법
1. Primary에서 replication 계정 생성:
   ```sql
   CREATE USER 'repl'@'%' IDENTIFIED BY 'repl';
   GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
   FLUSH PRIVILEGES;
   ```
2. Replica에서 Primary와 연결:
   ```sql
   STOP REPLICA;
   RESET REPLICA ALL;
   CHANGE MASTER TO
     MASTER_HOST='x.x.x.x',
     MASTER_PORT=x,
     MASTER_USER='id',
     MASTER_PASSWORD='pw',
     MASTER_AUTO_POSITION=1;
   START REPLICA;
   ```
3. 백업 계정 생성 (Primary에서 생성 → Replica로 복제):
   ```sql
   CREATE USER 'repl'@'localhost' IDENTIFIED BY 'pw';
   GRANT SELECT, PROCESS, LOCK TABLES, SHOW VIEW, TRIGGER, EVENT ON *.* TO 'backup'@'localhost';
   FLUSH PRIVILEGES;
   ```

---

## 6. 테스트 방법
1. Primary에서 테이블 생성 및 데이터 입력:
   ```sql
   USE fisa;
   CREATE TABLE repl_test(id INT PRIMARY KEY, msg VARCHAR(50));
   INSERT INTO repl_test VALUES (1, 'hello replication');
   ```
2. Replica에서 데이터 확인:
   ```sql
   USE fisa;
   SELECT * FROM repl_test;
   ```
3. 백업 스크립트 수동 실행 후 파일 확인:
   ```bash
   /usr/local/bin/mysqldump_backup.sh
   ls -lh /var/backups/mysql
   ```

---

## 7. 트러블슈팅
- `Replica_IO_Running: Connecting` → Primary 방화벽/계정 권한 확인  
- `Access denied` → `GRANT REPLICATION SLAVE` 다시 부여  
- `GTID 경고` → `--set-gtid-purged=OFF` 옵션 사용  
- `super_read_only 에러` → Primary에서 계정 생성 후 Replica에 자동 반영  

---

## 8. 벤더사별 백업 기술 비교

| DBMS        | 백업 방식                          | 특징                                   |
|-------------|-----------------------------------|----------------------------------------|
| **MySQL**   | `mysqldump`, XtraBackup, binlog   | 논리/물리 백업 모두 지원, GTID 기반 복제 |
| **Postgres**| `pg_dump`, `pg_basebackup`, WAL   | WAL 기반 Point-in-Time Recovery 강력    |
| **Oracle**  | RMAN                              | 증분/압축 백업, 엔터프라이즈 표준       |
| **MS SQL**  | Full / Incremental / Differential | GUI 관리 용이, 다양한 복구 모드         |
| **MongoDB** | `mongodump`, oplog                | JSON/BSON 단위, Replica Set 기반 백업   |

---

## 9. 향후 개선 아이디어
- Percona XtraBackup 적용 → 더 빠른 물리 백업  
- S3/NAS 업로드 → 외부 스토리지 이중화  
- Prometheus + Grafana → replication lag 모니터링  
- Docker Compose로 Primary/Replica/Backup 환경 자동화  
