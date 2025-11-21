<?php
// routes.php
// Incluye el router y lo inicializa

use function Auth\require_login;
use function Auth\checkAuthAndAdmin;

require_once __DIR__ . '/core/router.php';
require_once __DIR__ . '/Middleware/auth.php';

$router = new Router(); // detecta /FootBook automáticamente

/* ===== VISTAS (add) ===== */

$router->add('/FootBook',             'views/landing.php');
$router->add('/FootBook/home', function(){        
    require_login(); //Te redirige si no estás logueado
    require 'views/index.php';
}); 
$router->add('/FootBook/wiki',        'views/wiki.php'); 
$router->add('/FootBook/login',       'views/login.php');
$router->add('/FootBook/profile', function(){        
    require_login(); //Te redirige si no estás logueado
    require 'views/profile.php';
});
$router->add('/FootBook/signup',      'views/signup.php');
$router->add('/FootBook/admin', function(){        
    checkAuthAndAdmin(); //Te redirige si no estás logueado
    require 'views/admin.php';
});
$router->add('/FootBook/results',       'views/results.php');

/* ===== Controladores =====  */

    // ===== CATEGORIES ===== //
$router->get('/FootBook/api/categories',                'CategoryController@list'); //Lista 
$router->post('/FootBook/api/categories/:name',         'CategoryController@create'); //Crear
$router->post('/FootBook/api/categories/:id/update',    'CategoryController@update'); //Actualizar (usamos POST por compatibilidad)
$router->post('/FootBook/api/categories/:id/delete',    'CategoryController@delete'); //Eliminar (soft delete)

    // ===== USERS ===== //
$router->get('/FootBook/api/users',                     'UserController@index'); 
$router->post('/FootBook/api/users/register',           'UserController@register');
$router->post('/FootBook/api/users/login',              'UserController@login');
$router->get('/FootBook/api/users/me',                  'UserController@me');
$router->post('/FootBook/api/users/update',             'UserController@update');
$router->post('/FootBook/api/users/delete',             'UserController@delete');

    // ===== POSTS ===== //
$router->post('/FootBook/api/posts',                    'PostController@post'); //Crear post
$router->get('/FootBook/api/posts/to_approve',          'PostController@to_aproved'); //Obtener lista de posts para aprobar
$router->post('/FootBook/api/posts/:id/approve',        'PostController@approve_post');  //Aprobar o Denegar post
// FEED (scroll infinito)
$router->get('/FootBook/api/feed',                      'PostController@feed');
$router->post('/FootBook/api/posts/:id/like',           'LikeController@toggleLike');

    // ===== COMMENTS ===== //
$router->post('/FootBook/api/comments',                 'CommentController@comentar'); //Comentar publicación
$router->get('/FootBook/api/comments',                 'CommentController@index'); //Obtener Comentarios

    // ===== API WIKIS ===== //

/* ===== WorldCups ===== */
//$router->get('/FootBook/api/worldcups',                 'WorldCupApi@index');
$router->get('/FootBook/api/worldcups/light',           'WorldCupApi@lightindex');
//$router->get('/FootBook/api/worldcups/:id',             'WorldCupApi@show');




/* ===== Despacho ===== */
$router->dispatch();
