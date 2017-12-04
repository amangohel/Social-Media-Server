-module(a4).
-export([likeServer/1, numOfLikes/2, isPost/2, likePost/2,sleep/1,user/2,newUser/3,database/1,cache/2,postServer/1,postInnerServer/2,start/0]).

%Aman Gohel ag625

%Server - unchanged for question 4
%Parameter changed but functionality not changed.
%sends client data to cache
%receives data, either likes if a post exists
%or returns no post then recurses.
likeServer(Cache) ->
    receive
        {like, Post, Client} -> 
            Cache!{like, Post, self()},
           receive {dataReply, Data} ->
                case isPost(Data, Post) of
                  true -> L = numOfLikes(Data, Post),
                          Client!{likes, L+1},
                          likeServer(Cache);
                  false -> Client!{nopost},
                           likeServer(Cache)
                end
            end 

        end. 

%Adapted for question 4
%Database communicates with the likeServer.
%Returns the current state of the database.
%Returns number of posts in the database.
database(Data) ->
    receive
        {like, Post, Server} -> 
            Data2 = likePost(Data,Post),
            Server!{dataReply, Data},
            io:fwrite("DB: ~w~n", [Data2]),
            database(Data2);
        {post, Post, Innerserver} ->
            Data2 = lists:append(Data,[{Post, 0}]),
            io:fwrite("DB: ~w~n", [Data2]),
            Innerserver! {done},
            database(Data2)

    end.

%User (Client) for question 2
%Either likes a specific post
%Or there is no post to like, recurses until it finds one.
user(Username, Server) ->
    timer:sleep(rand:uniform(5000)),
    Post = rand:uniform(5),
    Server ! {like, Post, self()},
    receive
        {likes, Likes} ->
            io:format("~p: ~p likes on post ~p ~n", [Username, Likes, Post]),
            user(Username, Server);
        {nopost} ->
            io:format("~p: no post ~p ~n", [Username, Post]),
            user(Username, Server)
    end.

%Cache - Question 3
%Cache explanation
%The cache firstly sends the data to the server as data reply.
%the cache sends the data to the database.
%We then receive the reply with the updated value and store that within the cache.

%The impact on the user is tat they will always see the most updated values coming from the cache.

cache(Data, DB) ->
    receive
        {like, Post, Server} ->
            Server!{dataReply, Data},
            timer:sleep(500),
            DB ! {like, Post, self()},
        receive
          {dataReply, Data2} ->
            cache(Data2, DB)
        end
    end.

% ---- Question 4 Mutual Exclusion ----

%Locks the posting process so that only one client can post at a time.
%Spawns a new process to handle the post creation.
postServer(DB) ->
    receive
        {lock, Client} ->
            Session = spawn(?MODULE,postInnerServer,[DB,self()]),
            Client ! {session, Session},
            receive
                done -> postServer(DB)
                end
    end.
%Unlocks the posting process again so that other clients can create posts.
postInnerServer(DB, Parent) ->
   receive
    {post, Post} -> 
        DB ! {post, Post, self()},
        receive
        {done}-> postInnerServer(DB, Parent)
        end;
    {unlock} -> Parent ! done
end.



%New user for question 5 which tests functionality of question 4 (client) which can either like posts or create them.
%Depending on the decision made...
% 1 - The user will LIKE or NOT like a post.
% 2 - The user will create a new post.

%Implements mutual exclusion with PostServer.
newUser(Username, LikeServer, PostServer) ->
    Decision = rand:uniform(2),
    %Enables the user to continue liking posts...
    case Decision of
        
        1 -> 
            timer:sleep(rand:uniform(5000)),
            Post = rand:uniform(5),
            LikeServer ! {like, Post, self()},
            receive
                {likes, Likes} ->
                    io:format("~p: ~p likes on post ~p ~n", [Username, Likes, Post]),
                    newUser(Username, LikeServer, PostServer);
                {nopost} ->
                    io:format("~p: no post ~p ~n", [Username, Post]),
                    newUser(Username, LikeServer, PostServer)
            end;

            %Enables the user to create posts...
        2 ->    
            Post = rand:uniform(100) -1,
            PostServer ! {lock, self()},
            receive
                {session, Session} ->
                    Session ! {post, Post},
                    io:format("~p: created the post ~p ~n", [Username, Post]),
                    %unlocks session
                    Session ! {unlock},
                    newUser(Username, LikeServer, PostServer)
                end
        end.

%Required for sleep functionality.
sleep(T) ->
    receive
        after T ->
            true
    end.


%returns the number of likes.
numOfLikes([], _Post)                      -> 0;
numOfLikes([{Post, Likes} | _Posts], Post) -> Likes;
numOfLikes([_ | Posts], Post)              -> numOfLikes(Posts, Post).

%checks if value returned is a post.
isPost([], _Post)                  -> false;
isPost([{Post, _} | _Posts], Post) -> true;
isPost([_ | Posts], Post)          -> isPost(Posts, Post).

%a function that likes posts.
likePost([], _Post)                     -> [];
likePost([{Post, Likes} | Posts], Post) -> [{Post, Likes+1} | Posts];
likePost([P | Posts], Post)             -> [P | likePost(Posts, Post)].


%start
%spawns 5 processes relating to functionality of the system.
%spawns 5 client processes which can create posts and like posts.
start() -> 
    Data = [{1,1}, {2,1}, {3,1}, {4,1}, {5,1}],
    DB = spawn(?MODULE, database, [Data]),
    Cache = spawn(?MODULE, cache, [Data,DB]),
    Server = spawn(?MODULE, likeServer, [Cache]),
    PostServer = spawn(?MODULE, postServer, [DB]),


    %Client processes which used to interact with question 2 clients.
    % spawn(?MODULE, user, ["A", Server]),
    % spawn(?MODULE, user, ["B", Server]),
    % spawn(?MODULE, user, ["C", Server]),
    % spawn(?MODULE, user, ["D", Server]),
    % spawn(?MODULE, user, ["E", Server]),

    %Client processes that alternate between liking and creating posts.
    spawn(?MODULE, newUser, ["Bob", Server, PostServer]),
    spawn(?MODULE, newUser, ["Alan", Server, PostServer]),
    spawn(?MODULE, newUser, ["Steve", Server, PostServer]),
    spawn(?MODULE, newUser, ["Jim",Server, PostServer]),
    spawn(?MODULE, newUser, ["Jam",Server, PostServer]).