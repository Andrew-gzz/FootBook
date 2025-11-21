<?php
// controllers/PostController.php
declare(strict_types=1);

use Models\PostModel;

require_once __DIR__ . '/../models/PostModel.php';
require_once __DIR__ . '/../Middleware/auth.php';

use function Auth\current_user;

class PostController {
    private PostModel $model;

    public function __construct() {
        $this->model = new PostModel();
        header('Content-Type: application/json; charset=UTF-8');
    }

    /* ----------------- helpers ----------------- */
    private function json($data, int $code = 200): void
    {
        http_response_code($code);
        echo json_encode($data, JSON_UNESCAPED_UNICODE);
    }

    private function json_in(): array
    {
        // Acepta JSON y/x-www-form-urlencoded por compat
        $in = $_POST;
        if (empty($in)) {
            $raw = file_get_contents('php://input');
            if ($raw !== false && $raw !== '') {
                $j = json_decode($raw, true);
                if (is_array($j)) $in = $j;
            }
        }
        return $in ?: [];
    }

    private function json_out(int $code, array $payload): void
    {
        http_response_code($code);
        echo json_encode($payload, JSON_UNESCAPED_UNICODE);
    }

    public function post(): void
    {
        try {
            $in = $this->json_in();

            $required = [
                'category_id',
                'worldcup_id',
                'title',
                'description'
            ];

            foreach ($required as $r) {
                if (!isset($in[$r]) || trim((string)$in[$r]) === '') {
                    $this->json_out(422, ['ok'=>false,'error'=>"Campo requerido: $r"]);
                    return;
                }
            }
            
            // Normalizar datos
            $data = [
                'user_id' => (int)(current_user() ?? 0),
                'category_id' => isset($in['category_id']) ? (int)$in['category_id'] : 0,
                'worldcup_id' => isset($in['worldcup_id']) ? (int)$in['worldcup_id'] : 0,
                'team' => isset($in['team']) ? trim((string)$in['team']) : null,
                'title' => isset($in['title']) ? trim((string)$in['title']) : '',
                'description' => isset($in['description']) ? trim((string)$in['description']) : '',
                'media' => (isset($in['media']) && $in['media'] !== '')
                    ? base64_decode(preg_replace('#^data:image/\w+;base64,#i', '', $in['media']))
                    : null,
            ];

            $postId = $this->model->sp_create_post($data);

             $this->json_out(201, ['ok' => true, 'post_id' => $postId]);

        } catch (Throwable $e) {
            $code = (int)($e->getCode() ?: 500);
            $this->json_out($code, ['ok'=>false,'error'=>$e->getMessage()]);
        }
    }
    public function to_aproved(): void
    {
        try {
            $rows = $this->model->get_posts_to_approved();
            $this->json(['ok' => true, 'data' => $rows]);
        } catch (\Throwable $e) {
            $this->json(['ok' => false, 'error' => $e->getMessage()], 500);
        }
    }
    public function approve_post(?int $id = null): void
    {
        try {
            // Lee JSON (si no hay body, será null/[])
            $in = $this->json_in();

            // post_id puede venir en la ruta o en el body
            $postId = $id ?? (int)($in['post_id'] ?? 0);
            // is_approved debe ser 0 o 1
            $isApproved = $in['is_approved'] ?? $in['approve'] ?? null;
            $isApproved = ($isApproved === '' || $isApproved === null) ? null : (int)$isApproved;

            // Validaciones mínimas (el SP también valida, pero esto evita errores tontos)
            if ($postId <= 0) {
                $this->json_out(422, ['ok'=>false, 'error'=>'post_id inválido']);
                return;
            }
            if ($isApproved !== 0 && $isApproved !== 1) {
                $this->json_out(422, ['ok'=>false, 'error'=>'is_approved debe ser 0 o 1']);
                return;
            }

            $row = $this->model->approve_post([
                'post_id'     => $postId,
                'is_approved' => $isApproved,
            ]);

            // Respuesta JSON limpia
            $this->json_out(200, [
                'ok'   => true,
                'data' => $row, // ej: { id, approved, approved_at }
            ]);

        } catch (\Throwable $e) {
            $code = (int)($e->getCode() ?: 500);
            $this->json_out($code, ['ok'=>false,'error'=>$e->getMessage()]);
        }
    }
    public function feed(): void
    {
        try {
            // Query params
            $after      = isset($_GET['after'])       ? (int)$_GET['after']       : 0;
            $limit      = isset($_GET['limit'])       ? (int)$_GET['limit']       : 10;
            $categoryId = isset($_GET['category_id']) ? (int)$_GET['category_id'] : 0;
            $worldcupId = isset($_GET['worldcup_id']) ? (int)$_GET['worldcup_id'] : 0;
            $order      = isset($_GET['order'])       ? (string)$_GET['order']    : 'cronologico';
            $searchText = isset($_GET['q'])           ? trim((string)$_GET['q'])  : ''; 

            // Si viene user_id en el querystring (perfil), úsalo para filtrar por autor
            // Si no viene, queda 0 => feed general
            $authorId   = isset($_GET['user_id']) ? (int)$_GET['user_id'] : 0;

            // Llama al model (pasa parámetros exactamente en el orden del SP)
            $rows = $this->model->get_feed($authorId, $after, $limit, $categoryId, $worldcupId, $order, $searchText);

            $this->json(['ok' => true, 'data' => $rows]);
        } catch (\Throwable $e) {
            $this->json(['ok' => false, 'error' => $e->getMessage()], 500);
        }
    }

}