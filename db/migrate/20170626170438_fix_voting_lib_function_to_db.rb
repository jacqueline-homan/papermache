class FixVotingLibFunctionToDb < ActiveRecord::Migration
  def change
    execute "-- FUNCTION: public.get_paper_sma(integer)

 DROP FUNCTION public.get_paper_sma(integer);

CREATE OR REPLACE FUNCTION public.get_paper_sma(
	paper_id integer)
    RETURNS double precision
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$
            declare
            voted_user_cnt integer;
            vote_sum integer;
            row RECORD;
            ACCOUNT_ID INTEGER;
            Begin
            select count(1) into voted_user_cnt from
            (
            select voter_id, count(*) from votes
            where votable_type = 'Papermache::Paper'
            and votable_id = paper_id
            group by voter_id
                ) as tbl;
            if voted_user_cnt = 0 then
              return 0;
            end if;
            vote_sum := 0;
            for row in (select voter_id from
                            votes
                            where votable_type = 'Papermache::Paper'
                            and votable_id = paper_id
                            group by voter_id) 
            loop
              SELECT AC.ID INTO ACCOUNT_ID FROM ACCOUNTS AC WHERE AC.STUDENT_ID = row.voter_id;
              vote_sum := vote_sum + abs(get_paper_user_score(paper_id, ACCOUNT_ID));
            end loop;

            return vote_sum / voted_user_cnt;
                        
            End

            
$function$;

ALTER FUNCTION public.get_paper_sma(integer)
    OWNER TO postgres;


-- FUNCTION: public.get_paper_user_gainlosses(integer, integer)

 DROP FUNCTION public.get_paper_user_gainlosses(integer, integer);

CREATE OR REPLACE FUNCTION public.get_paper_user_gainlosses(
	paper_id integer,
	user_id integer)
    RETURNS double precision
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

            DECLARE
            RET DOUBLE PRECISION;
            SCORE INTEGER;
            PAPER_SMA DOUBLE PRECISION;
            BEGIN
            SCORE := GET_PAPER_USER_SCORE(PAPER_ID, USER_ID);
            PAPER_SMA := GET_PAPER_SMA(PAPER_ID);

            IF SCORE > 0 THEN
              RET := (PAPER_SMA + SCORE) / 2;
            ELSEIF SCORE = 0 THEN
              RET := 0.0;
            ELSE
              RET := 1 - (PAPER_SMA + SCORE) / 2;
            END IF;
            RETURN RET; 
            END

            
$function$;

ALTER FUNCTION public.get_paper_user_gainlosses(integer, integer)
    OWNER TO postgres;

-- FUNCTION: public.get_paper_user_score(integer, integer)

 DROP FUNCTION public.get_paper_user_score(integer, integer);

CREATE OR REPLACE FUNCTION public.get_paper_user_score(
	paper_id integer,
	user_id integer)
    RETURNS integer
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$
            declare
            vote_up integer := 0;
            vote_down integer :=0;
            score integer;
            STUDENT_ID INTEGER;
            begin
            SELECT AC.STUDENT_ID INTO STUDENT_ID FROM ACCOUNTS AC WHERE AC.ID = USER_ID;
            
            select COALESCE(sum(vote_weight),0) into vote_up from votes
            where votable_type = 'Papermache::Paper'
            and votable_id = paper_id
            and voter_id = STUDENT_ID
            and vote_flag = true;

            select COALESCE(sum(vote_weight),0) into vote_down from votes
            where votable_type = 'Papermache::Paper'
            and votable_id = paper_id
            and voter_id = STUDENT_ID
            and vote_flag = false;

            score := vote_up - vote_down;
            return score;
            end

            
$function$;

ALTER FUNCTION public.get_paper_user_score(integer, integer)
    OWNER TO postgres;

-- FUNCTION: public.get_user_allpaper_votescore(integer)

DROP FUNCTION public.get_user_allpaper_votescore(integer);

CREATE OR REPLACE FUNCTION public.get_user_allpaper_votescore(
	user_id integer)
    RETURNS integer
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$
            DECLARE
            RET INTEGER := 0;
            BEGIN

            SELECT COALESCE(SUM(CACHED_WEIGHTED_SCORE), 0) INTO RET FROM PAPERS
            WHERE
            ACCOUNT_ID = USER_ID;

            RETURN RET;
            END

            
$function$;

ALTER FUNCTION public.get_user_allpaper_votescore(integer)
    OWNER TO postgres;

-- FUNCTION: public.get_user_reputation(integer)

DROP FUNCTION public.get_user_reputation(integer);

CREATE OR REPLACE FUNCTION public.get_user_reputation(
	user_id integer)
    RETURNS double precision
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$
            DECLARE
            RET DOUBLE PRECISION := 0.0;
            ALL_VOTES_SCORE INTEGER := 0;
            ALL_GAINLOSSES DOUBLE PRECISION := 0.0;
           	STUDENT_ID INTEGER := 0;
            BEGIN
			SELECT AC.STUDENT_ID INTO STUDENT_ID FROM ACCOUNTS AC WHERE AC.ID = USER_ID;
            ALL_VOTES_SCORE := GET_USER_ALLPAPER_VOTESCORE(USER_ID);
			
            select COALESCE(sum(GAIN_LOSSES), 0.0) INTO ALL_GAINLOSSES from 
            (
            SELECT DISTINCT(VOTABLE_ID) ,  get_paper_user_gainlosses(votable_id, USER_ID) GAIN_LOSSES FROM VOTES
            WHERE 
            VOTABLE_TYPE = 'Papermache::Paper'
            AND VOTER_ID = STUDENT_ID
            ) as tbl;
            RET := ALL_VOTES_SCORE + ALL_GAINLOSSES;
            RETURN RET;
            END

            
$function$;

ALTER FUNCTION public.get_user_reputation(integer)
    OWNER TO postgres;

"
  end
end
