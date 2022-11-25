#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include "..\usr\include\GL\freeglut.h"
#include <stdio.h>
#include <time.h>
#include <math.h>


//콜백 함수
void Render();
void Reshape(int w, int h);
void Timer(int id);

//사용자 정의 함수
void CreateTree();
void Treedraw(float* location, int start);
__global__ void TreeKernel(float* dev_location, float* dev_angle, float len, int find, float angular);


#define TILE_WIDTH 32
const int Dim = 1024;
float* location;
float* angle;
float len = 0.15;
int num = 1;
int start = 0;
float angular = 0.0f;

int main(int argc, char** argv)
{
	printf("차수:");
	scanf_s("%d", &num);
	printf("각도:");
	scanf_s("%f", &angular);
	location = (float*)malloc(sizeof(float) * 2 * 3);
	angle = (float*)malloc(sizeof(float) * 3);
	for (int i = 0; i < 6; i += 2)
	{
		location[i] = 0.0f;
		location[i + 1] = -0.5f;
	}
	for (int i = 0; i < 3; i++)
	{
		angle[i] = 0;
	}

	//GLUT 초기화
	glutInit(&argc, argv);
	glutInitDisplayMode(GLUT_RGB);

	//윈도우 크기 설정 및 생성
	glutInitWindowSize(Dim, Dim);
	glutCreateWindow("Fractal Tree(GPU)");

	//콜백 함수 등록
	glutDisplayFunc(Render);
	glutReshapeFunc(Reshape);
	glutTimerFunc(300, Timer, 0);

	cudaSetDevice(0);

	//이벤트 처리 루프 진입
	glutMainLoop();

	cudaDeviceReset();
	return 0;
}

void Treedraw(float* location, int start)
{
	if (start == 1)
	{
		glColor3f(0.58, (float)1 / num, 0);
		glLineWidth(3.0f);
		glBegin(GL_LINES);
		glVertex2f(location[0], location[1]);
		glVertex2f(0.0, -1.0);
	}

	int k = 0;
	int n = 0;
	float g = (float)1 / num;
	float r = (float)0.58 / num;
	for (int i = 0; i < (pow(2, start - 1) - 1); i++)
	{
		// 차수에 따른 색상 변경을 위한 코드
		if (k > pow(2, n))
		{
			g += (float)1 / num;
			r += (float)0.58 / num;
			n++;
		}
		// Left Tree
		glColor3f(0.58 - r, g, 0);
		glLineWidth(3.0f);
		glBegin(GL_LINES);
		glVertex2f(location[2 * i], location[2 * i + 1]);
		glVertex2f(location[4 * i + 2], location[4 * i + 3]);

		// Right Tree
		glColor3f(0.58 - r, g, 0);
		glLineWidth(3.0f);
		glBegin(GL_LINES);
		glVertex2f(location[2 * i], location[2 * i + 1]);
		glVertex2f(location[4 * i + 4], location[4 * i + 5]);
		k++;
	}
	glEnd();
}


void Render()
{
	if (num < start)
	{
		exit(0);
	}
	CreateTree();
	Treedraw(location, start);
	len = 0.89 * len;
	start++;
	int need = pow(2, start + 2) - 1;
	location = (float*)realloc(location, sizeof(float) * 2 * need);
	angle = (float*)realloc(angle, sizeof(float) * need);
	glFinish();
}

void Reshape(int w, int h)
{
	glViewport(0, 0, w, h);
}



void Timer(int id)
{
	glutPostRedisplay();
	glutTimerFunc(500, Timer, 0);
}

void CreateTree()
{
	// 좌표 저장 배열의 인덱스 계산을 위한 변수 find, check
	int find = pow(2, start + 2) - 1;		// 전체 트리를 그리는데 필요한 좌표의 총 개수
	int check = pow(2, start);				// 연산을 진행할 좌표의 개수

	float* dev_location;	// GPU 내에서 좌표를 저장하기 위한 배열
	float* dev_angle;		// GPU 내에서 좌표마다의 각도를 저장하기 위한 배열

	cudaError_t cudaStatus = cudaSetDevice(0);
	cudaMalloc((void**)&dev_location, sizeof(float) * 2 * find);
	cudaMalloc((void**)&dev_angle, sizeof(float) * find);
	cudaMemcpy(dev_location, location, sizeof(float) * 2 * find, cudaMemcpyHostToDevice);
	cudaMemcpy(dev_angle, angle, sizeof(float) * find, cudaMemcpyHostToDevice);

	dim3 gridDim(128, 128);
	dim3 blockDim(TILE_WIDTH, TILE_WIDTH);

	clock_t st = clock();
	TreeKernel << <gridDim, blockDim >> > (dev_location, dev_angle, len, check, angular);
	cudaDeviceSynchronize();

	cudaMemcpy(location, dev_location, sizeof(float) * 2 * find, cudaMemcpyDeviceToHost);
	cudaMemcpy(angle, dev_angle, sizeof(float) * find, cudaMemcpyDeviceToHost);

	cudaFree(dev_location);
	cudaFree(dev_angle);

	if (start > 0)
		printf("%d번째 Elapsed time = %u ms\n", start, clock() - st);
}

__global__ void TreeKernel(float* dev_location, float* dev_angle, float len, int check, float angular)
{
	int x = blockIdx.x * TILE_WIDTH + threadIdx.x;
	int y = blockIdx.y * TILE_WIDTH + threadIdx.y;

	int index = x + y * 4096;
	int destination = 2 * (check - 1) + 2 * index;	// 다음 트리의 좌표 저장을 위한 인덱스

	// 현재 index (0 ~ check-1) 까지 dev_location에 좌표들이 저장되어 있음
	if (index < check)
	{
		float a = dev_location[destination];
		float b = dev_location[destination + 1];
		float angle = dev_angle[check - 1 + index];

		// 왼쪽 트리의 x,y 좌표
		float lx = a + len * sin(angle - angular);
		float ly = b + len * cos(angle - angular);
		dev_location[2 * destination + 2] = lx;
		dev_location[2 * destination + 3] = ly;
		dev_angle[2 * check + 2 * index - 1] = angle - angular;		// 오른쪽 트리로 향하는 각도 저장

		// 오른쪽 트리의 x,y 좌표
		float rx = a + len * sin(angle + angular);
		float ry = b + len * cos(angle + angular);
		dev_location[2 * destination + 4] = rx;
		dev_location[2 * destination + 5] = ry;
		dev_angle[2 * check + 2 * index] = angle + angular;		// 왼쪽 트리로 향하는 각도 저장
	}
}