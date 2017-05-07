-- Table: public.accounts

-- DROP TABLE public.accounts;

CREATE TABLE public.messages
(    
    recipient text,
    sendername text,
    message text,
    messagestatus text,
    messageid BIGINT, 
    timestamp TIMESTAMP,
    canonical_id BIGINT,
    multicast_id BIGINT,
    CONSTRAINT messageid PRIMARY KEY (messageid)
)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;

ALTER TABLE public.messages
    OWNER to mentormenteeapp;

-- Table: public.accounts

-- DROP TABLE public.accounts;




CREATE TABLE public.accounts
(
    full_name text COLLATE pg_catalog."default",
    email text COLLATE pg_catalog."default" NOT NULL,
    mentor boolean,
    mentee boolean,
    fcm_id text COLLATE pg_catalog."default",
    pne_status text COLLATE pg_catalog."default",
    device_type text COLLATE pg_catalog."default",
    CONSTRAINT email PRIMARY KEY (email)
)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;

ALTER TABLE public.accounts
    OWNER to mentormenteeapp;


