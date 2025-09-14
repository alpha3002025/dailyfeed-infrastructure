-- members
create table if not exists dailyfeed.members
(
    id                 bigint auto_increment PRIMARY KEY,
    email              varchar(100) null,
    password           varchar(100)  null,
    name               varchar(100) null,
    roles              varchar(100) null,
    created_at         datetime     null,
    updated_at         datetime     null,
    constraint member_unique_email
    unique (email)
);

-- member_follow
create table if not exists dailyfeed.member_follows
(
    id           bigint auto_increment PRIMARY KEY,
    follower_id  bigint null,
    following_id bigint null
);

-- member_profiles
create table if not exists dailyfeed.member_profiles
(
    id                  bigint auto_increment primary key,
    member_id           bigint not null,
    member_name         varchar(100) not null,
    handle              varchar(50) not null unique,
    display_name        varchar(100), -- 표시용 이름 (이모지, 특수문자 포함 가능)
    bio text,
    location            varchar(100),
    website_url         varchar(500),
    birth_date          date,
    gender              varchar(30),    -- 'male', 'female', 'other', 'prefer_not_to_say'
    timezone            varchar(50) default 'utc',
    language_code       varchar(10) default 'en',
    country_code        char(2),
    verification_status varchar(20),    -- 'none', 'pending', 'verified' default 'none'
    privacy_level       varchar(20),    -- 'public', 'friends', 'private' default 'public'
    profile_completion_score tinyint default 0,
    is_active boolean default true,
    created_at timestamp default current_timestamp,
    updated_at timestamp default current_timestamp on update current_timestamp,

    index idx_member_id (member_id),
    index idx_handle (handle),
    index idx_country_lang (country_code, language_code),
    index idx_verification (verification_status),
    index idx_updated_at (updated_at)

    -- FOREIGN KEY (member_id) REFERENCES members(member_id) ON DELETE CASCADE
);

-- member_profile_images
create table if not exists dailyfeed.member_profile_images
(
    image_id            bigint primary key auto_increment,
    profile_id          bigint not null,
    image_type          varchar(20), -- 'avatar', 'cover', 'gallery' default 'avatar'
    image_category      varchar(20) not null, -- 'original', 'small', 'medium', 'large', 'thumbnail' not null
    image_url           varchar(1000) not null,
    image_path          varchar(500),
    file_size           bigint unsigned,
    width               smallint unsigned,
    height              smallint unsigned,
    mime_type           varchar(50),
    cdn_url             varchar(1000),
    is_primary          boolean default false,
    upload_source       varchar(50),
    created_at          timestamp default current_timestamp,
    updated_at          timestamp default current_timestamp on update current_timestamp,

    index idx_profile_id (profile_id),
    index idx_profile_type_category (profile_id, image_type, image_category),
    index idx_primary (profile_id, is_primary),

    -- foreign key (profile_id) references member_profiles(profile_id) on delete cascade,
    unique key unique_primary_avatar (profile_id, image_type, is_primary)
);


-- comments
create table if not exists dailyfeed.comments
(
    id         bigint auto_increment PRIMARY KEY,
    content    text       not null,
    author_id  bigint     not null,
    post_id    bigint     not null,
    parent_id  bigint     null,
    is_deleted tinyint(1) null,
    depth      int(11) null,
    like_count bigint     null,
    created_at datetime     null,
    updated_at datetime     null
);

-- posts
create table if not exists dailyfeed.posts
(
    id                 bigint auto_increment PRIMARY KEY,
    title              varchar(100) null,
    content            text         null,
    author_id          bigint       not null,
    view_count         bigint       null,
    like_count         bigint       null,
    is_deleted         tinyint(1)   null,
    created_at         datetime     null,
    updated_at         datetime     null
);

-- jwt_keys
create table if not exists dailyfeed.jwt_keys
(
    id                 bigint auto_increment PRIMARY KEY,
    key_id             varchar(255) null,
    secret_key         varchar(255) not null,
    is_active          tinyint(1)   not null,
    expires_at         datetime     null,
    is_primary         tinyint(1)   not null,
    created_at       datetime     null,
    updated_at datetime     null
);



-- SEASON 2
-- handle (닉네임(사용자명)) 변경 이력 추적 테이블
-- create table dailyfeed.member_handle_history (
--     history_id bigint primary key auto_increment,
--     profile_id bigint not null,
--     old_handle varchar(50),
--     new_handle varchar(50),
--     changed_at timestamp default current_timestamp,
--     reason varchar(100),
--
--     index idx_profile_id (profile_id),
--     index idx_handles (old_handle, new_handle),
--
--     foreign key (profile_id) references member_profiles(profile_id)
-- );
--
-- -- handle(닉네임(사용자명)) 예약어/금지어 단어 테이블
-- create table dailyfeed.reserved_handles (
--     handle varchar(50) primary key,
--     reason enum('system', 'brand', 'inappropriate', 'reserved') not null,
--     created_at timestamp default current_timestamp
-- );
--
-- -- 프로필 다국어 정보 테이블
-- create table dailyfeed.member_profile_i18n (
--     i18n_id bigint primary key auto_increment,
--     profile_id bigint not null,
--     language_code varchar(10) not null,
--     localized_name varchar(100),
--     localized_bio text,
--
--     unique key unique_profile_lang (profile_id, language_code),
--     foreign key (profile_id) references member_profiles(profile_id) on delete cascade
-- );
--
-- -- 프로필 캐시 메타데이터
-- create table dailyfeed.member_profile_cache (
--     profile_id bigint primary key,
--     cache_key varchar(100) unique,
--     cached_data json,
--     cache_expires_at timestamp,
--     cache_version smallint default 1,
--
--     index idx_cache_key (cache_key),
--     index idx_expires (cache_expires_at),
--
--     foreign key (profile_id) references member_profiles(profile_id) on delete cascade
-- );